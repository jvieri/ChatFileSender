import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/file_attachment.dart';
import '../../domain/repositories/chat_message_repository.dart';
import '../../services/signalr_service.dart';

part 'chat_event.dart';
part 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatMessageRepository _messageRepository;
  final SignalRService _signalRService;
  late final StreamSubscription<bool> _connectionSub;

  ChatBloc({
    required ChatMessageRepository messageRepository,
    required SignalRService signalRService,
  })  : _messageRepository = messageRepository,
        _signalRService = signalRService,
        super(const ChatState()) {
    on<LoadMessagesEvent>(_onLoadMessages);
    on<SendMessageEvent>(_onSendMessage);
    on<SendFileMessageEvent>(_onSendFileMessage);
    on<ReceiveMessageEvent>(_onReceiveMessage);
    on<UpdateFileProgressEvent>(_onUpdateFileProgress);
    on<UpdateFileCompletedEvent>(_onUpdateFileCompleted);
    on<UpdateFileErrorEvent>(_onUpdateFileError);
    on<JoinChatEvent>(_onJoinChat);
    on<LeaveChatEvent>(_onLeaveChat);
    on<LoadMoreMessagesEvent>(_onLoadMoreMessages);
    on<SimulateReceiveMessageEvent>(_onSimulateReceiveMessage);
    on<_ConnectionStateChangedEvent>(_onConnectionStateChanged);

    // Setup SignalR listeners
    _setupSignalRListeners();
  }
  
  void _setupSignalRListeners() {
    _connectionSub = _signalRService.connectionStateStream.listen((connected) {
      add(_ConnectionStateChangedEvent(connected));
    });

    _signalRService.messageStream.listen((messageData) {
      // Parse and add to state
      add(ReceiveMessageEvent(_parseMessageFromSignalR(messageData)));
    });
    
    _signalRService.fileProgressStream.listen((data) {
      final fileId = data['fileId'] as String?;
      final progress = data['progress'] as int? ?? 0;
      final status = data['status'] as String? ?? 'Uploading';
      
      if (fileId != null) {
        add(UpdateFileProgressEvent(fileId, progress, _parseUploadStatus(status)));
      }
    });
    
    _signalRService.fileCompletedStream.listen((data) {
      final fileId = data['fileId'] as String?;
      if (fileId != null) {
        add(UpdateFileCompletedEvent(fileId));
      }
    });
    
    _signalRService.fileErrorStream.listen((data) {
      final fileId = data['fileId'] as String?;
      final errorMessage = data['errorMessage'] as String? ?? 'Unknown error';
      
      if (fileId != null) {
        add(UpdateFileErrorEvent(fileId, errorMessage));
      }
    });
  }
  
  Future<void> _onLoadMessages(
    LoadMessagesEvent event,
    Emitter<ChatState> emit,
  ) async {
    emit(state.copyWith(
      isLoading: true,
      userId: event.userId,
      groupId: event.groupId,
    ));

    final result = event.groupId != null
        ? await _messageRepository.getGroupMessages(
            groupId: event.groupId!,
            page: 1,
          )
        : await _messageRepository.getDirectMessages(
            userId: event.userId!,
            page: 1,
          );

    result.fold(
      (failure) => emit(state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      )),
      (messages) => emit(state.copyWith(
        isLoading: false,
        userId: event.userId,
        groupId: event.groupId,
        messages: messages.reversed.toList(), // Show oldest first
        hasMore: messages.length >= 50,
        currentPage: 1,
      )),
    );
  }
  
  Future<void> _onLoadMoreMessages(
    LoadMoreMessagesEvent event,
    Emitter<ChatState> emit,
  ) async {
    if (state.isLoading || !state.hasMore) return;
    
    final nextPage = state.currentPage + 1;
    
    final result = state.groupId != null
        ? await _messageRepository.getGroupMessages(
            groupId: state.groupId!,
            page: nextPage,
          )
        : await _messageRepository.getDirectMessages(
            userId: state.userId ?? '',
            page: nextPage,
          );
    
    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (messages) {
        final allMessages = [...messages.reversed, ...state.messages];
        emit(state.copyWith(
          messages: allMessages,
          hasMore: messages.length >= 50,
          currentPage: nextPage,
        ));
      },
    );
  }
  
  Future<void> _onSendMessage(
    SendMessageEvent event,
    Emitter<ChatState> emit,
  ) async {
    if (event.textContent.trim().isEmpty) return;

    // Optimistic: show message immediately with a temp id
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMessage = ChatMessage(
      id: tempId,
      senderId: ChatMessage.currentUserId,
      senderName: 'You',
      receiverId: state.userId,
      groupId: state.groupId,
      textContent: event.textContent,
      messageType: MessageType.text,
      createdAt: DateTime.now(),
    );
    emit(state.copyWith(messages: [...state.messages, tempMessage]));

    final result = await _messageRepository.sendMessage(
      receiverId: state.userId,
      groupId: state.groupId,
      textContent: event.textContent,
    );

    result.fold(
      (failure) {
        // Remove temp message on failure
        final msgs = state.messages.where((m) => m.id != tempId).toList();
        emit(state.copyWith(messages: msgs, errorMessage: failure.message));
      },
      (message) {
        // Replace temp message with the server-confirmed one (dedup by id)
        final msgs = state.messages
            .where((m) => m.id != tempId && m.id != message.id)
            .toList()
          ..add(message);
        emit(state.copyWith(messages: msgs, errorMessage: null));
      },
    );
  }
  
  Future<void> _onSendFileMessage(
    SendFileMessageEvent event,
    Emitter<ChatState> emit,
  ) async {
    if (event.attachments.isEmpty) return;

    // ── 1. Show message immediately with files at 0 % uploading ──────────────
    final tempId = 'temp_file_${DateTime.now().millisecondsSinceEpoch}';
    final uploadingAttachments = event.attachments
        .map((f) => f.copyWith(
              uploadStatus: UploadStatus.uploading,
              uploadProgress: 0,
            ))
        .toList();

    emit(state.copyWith(messages: [
      ...state.messages,
      ChatMessage(
        id: tempId,
        senderId: ChatMessage.currentUserId,
        senderName: 'You',
        receiverId: state.userId,
        groupId: state.groupId,
        textContent: event.textContent,
        messageType: MessageType.file,
        attachments: uploadingAttachments,
        createdAt: DateTime.now(),
      ),
    ]));

    // ── 2. Create message record on server + get server file IDs ─────────────
    final createResult = await _messageRepository.createMessageWithFiles(
      receiverId: state.userId,
      groupId: state.groupId,
      textContent: event.textContent,
      files: event.attachments,
    );

    MessageWithFilesResult? serverData;
    String? createError;
    createResult.fold(
      (failure) => createError = failure.message,
      (r) => serverData = r,
    );

    if (createError != null) {
      final msgs = state.messages.where((m) => m.id != tempId).toList();
      emit(state.copyWith(messages: msgs, errorMessage: createError));
      return;
    }

    // ── 3. Upload each file; emit progress into the temp message bubble ───────
    for (int i = 0;
        i < event.attachments.length && i < serverData!.serverFileIds.length;
        i++) {
      final clientFile = event.attachments[i];
      final serverFileId = serverData!.serverFileIds[i];

      if (clientFile.localFilePath == null) continue;

      try {
        await for (final progress in _messageRepository.uploadFileDirect(
          serverFileId: serverFileId,
          localFilePath: clientFile.localFilePath!,
          fileType: clientFile.fileType,
        )) {
          final updatedMsgs = state.messages.map((m) {
            if (m.id != tempId) return m;
            final updatedAttachments = m.attachments.map((a) {
              if (a.id != clientFile.id) return a;
              return a.copyWith(
                uploadProgress: progress.clamp(0, 100),
                uploadStatus: progress >= 100
                    ? UploadStatus.completed
                    : UploadStatus.uploading,
              );
            }).toList();
            return m.copyWith(attachments: updatedAttachments);
          }).toList();
          emit(state.copyWith(messages: updatedMsgs));
        }
      } catch (e) {
        debugPrint('[ChatBloc] upload error for $serverFileId: $e');
        final updatedMsgs = state.messages.map((m) {
          if (m.id != tempId) return m;
          final updatedAttachments = m.attachments.map((a) {
            if (a.id != clientFile.id) return a;
            return a.copyWith(
              uploadStatus: UploadStatus.failed,
              errorMessage: e.toString(),
            );
          }).toList();
          return m.copyWith(attachments: updatedAttachments);
        }).toList();
        emit(state.copyWith(messages: updatedMsgs));
      }
    }
  }
  
  void _onReceiveMessage(
    ReceiveMessageEvent event,
    Emitter<ChatState> emit,
  ) {
    // Check if message already exists
    if (state.messages.any((m) => m.id == event.message.id)) return;
    
    // Only add if message belongs to this chat
    final belongsToThisChat = (state.groupId != null && event.message.groupId == state.groupId) ||
        (state.userId != null && event.message.receiverId == state.userId) ||
        event.message.senderId == state.userId;
    
    if (!belongsToThisChat) return;
    
    final updatedMessages = [...state.messages, event.message];
    emit(state.copyWith(messages: updatedMessages));
  }
  
  void _onUpdateFileProgress(
    UpdateFileProgressEvent event,
    Emitter<ChatState> emit,
  ) {
    final updatedMessages = state.messages.map((m) {
      final updatedAttachments = m.attachments.map((a) {
        if (a.id == event.fileId) {
          return a.copyWith(
            uploadProgress: event.progress,
            uploadStatus: event.status,
          );
        }
        return a;
      }).toList();
      
      if (m.attachments.any((a) => a.id == event.fileId)) {
        return m.copyWith(attachments: updatedAttachments);
      }
      return m;
    }).toList();
    
    emit(state.copyWith(messages: updatedMessages));
  }
  
  void _onUpdateFileCompleted(
    UpdateFileCompletedEvent event,
    Emitter<ChatState> emit,
  ) {
    final updatedMessages = state.messages.map((m) {
      final updatedAttachments = m.attachments.map((a) {
        if (a.id == event.fileId) {
          return a.copyWith(
            uploadStatus: UploadStatus.completed,
          );
        }
        return a;
      }).toList();
      
      if (m.attachments.any((a) => a.id == event.fileId)) {
        return m.copyWith(attachments: updatedAttachments);
      }
      return m;
    }).toList();
    
    emit(state.copyWith(messages: updatedMessages));
  }
  
  void _onUpdateFileError(
    UpdateFileErrorEvent event,
    Emitter<ChatState> emit,
  ) {
    final updatedMessages = state.messages.map((m) {
      final updatedAttachments = m.attachments.map((a) {
        if (a.id == event.fileId) {
          return a.copyWith(
            uploadStatus: UploadStatus.failed,
            errorMessage: event.errorMessage,
          );
        }
        return a;
      }).toList();
      
      if (m.attachments.any((a) => a.id == event.fileId)) {
        return m.copyWith(attachments: updatedAttachments);
      }
      return m;
    }).toList();
    
    emit(state.copyWith(messages: updatedMessages));
  }
  
  Future<void> _onJoinChat(
    JoinChatEvent event,
    Emitter<ChatState> emit,
  ) async {
    try {
      await _signalRService.joinChat(event.chatId);
    } catch (e) {
      debugPrint('[ChatBloc] joinChat error: $e');
    }
    emit(state.copyWith(
      chatId: event.chatId,
      isConnected: _signalRService.isConnected,
    ));
  }

  void _onConnectionStateChanged(
    _ConnectionStateChangedEvent event,
    Emitter<ChatState> emit,
  ) {
    emit(state.copyWith(isConnected: event.connected));
  }
  
  Future<void> _onLeaveChat(
    LeaveChatEvent event,
    Emitter<ChatState> emit,
  ) async {
    await _signalRService.leaveChat(event.chatId);
    emit(state.copyWith(isConnected: false));
  }
  
  void _onSimulateReceiveMessage(
    SimulateReceiveMessageEvent event,
    Emitter<ChatState> emit,
  ) {
    // Create a simulated incoming message
    final simulatedMessage = ChatMessage(
      id: UniqueKey().toString(),
      senderId: event.senderId,
      senderName: event.senderName,
      receiverId: state.userId,
      groupId: state.groupId,
      textContent: event.textContent,
      messageType: MessageType.text,
      createdAt: DateTime.now(),
    );
    
    final updatedMessages = [...state.messages, simulatedMessage];
    emit(state.copyWith(messages: updatedMessages));
  }
  
  ChatMessage _parseMessageFromSignalR(Map<String, dynamic> data) {
    return ChatMessage(
      id: data['messageId'] as String,
      senderId: data['senderId'] as String,
      senderName: data['senderName'] ?? '',
      receiverId: data['receiverId'] as String?,
      groupId: data['groupId'] as String?,
      textContent: data['textContent'] as String?,
      messageType: _parseMessageType(data['messageType'] as String? ?? 'Text'),
      attachments: [],
      createdAt: DateTime.parse(data['createdAt'] as String),
    );
  }
  
  MessageType _parseMessageType(String type) {
    switch (type.toLowerCase()) {
      case 'text': return MessageType.text;
      case 'file': return MessageType.file;
      case 'image': return MessageType.image;
      case 'video': return MessageType.video;
      case 'system': return MessageType.system;
      default: return MessageType.text;
    }
  }
  
  UploadStatus _parseUploadStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return UploadStatus.pending;
      case 'uploading': return UploadStatus.uploading;
      case 'uploaded': return UploadStatus.uploaded;
      case 'processing': return UploadStatus.processing;
      case 'completed': return UploadStatus.completed;
      case 'failed': return UploadStatus.failed;
      case 'cancelled': return UploadStatus.cancelled;
      default: return UploadStatus.pending;
    }
  }
  
  @override
  Future<void> close() {
    _connectionSub.cancel();
    _signalRService.dispose();
    return super.close();
  }
}
