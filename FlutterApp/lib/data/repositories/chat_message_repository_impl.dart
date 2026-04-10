import 'dart:async';
import 'package:dio/dio.dart';
import '../../core/constants.dart';
import '../../core/use_result.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/file_attachment.dart';
import '../../domain/repositories/chat_message_repository.dart';

class ChatMessageRepositoryImpl implements ChatMessageRepository {
  final Dio dio;
  
  ChatMessageRepositoryImpl(this.dio);
  
  @override
  Future<Either<Failure, ChatMessage>> sendMessage({
    String? receiverId,
    String? groupId,
    String? textContent,
  }) async {
    try {
      final response = await dio.post(
        '${AppConstants.apiVersion}/messages',
        data: {
          'receiverId': receiverId,
          'groupId': groupId,
          'textContent': textContent,
        },
      );
      
      final data = response.data as Map<String, dynamic>;
      final message = _parseMessage(data);
      
      return Right(message);
    } on DioException catch (e) {
      return Left(NetworkFailure(message: e.message ?? 'Failed to send message'));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, MessageWithFilesResult>> createMessageWithFiles({
    String? receiverId,
    String? groupId,
    String? textContent,
    required List<FileAttachment> files,
  }) async {
    try {
      final response = await dio.post(
        '${AppConstants.apiVersion}/messages/with-file',
        data: {
          'receiverId': receiverId,
          'groupId': groupId,
          'textContent': textContent,
          'files': files
              .map((f) => {
                    'fileName': f.fileName,
                    'fileSize': f.fileSize,
                    'fileType': f.fileType,
                  })
              .toList(),
        },
      );
      final data = response.data as Map<String, dynamic>;
      final messageId = data['messageId'] as String;
      final uploadUrls = (data['uploadUrls'] as List);
      final serverFileIds = uploadUrls
          .map((u) => (u as Map<String, dynamic>)['fileId'] as String)
          .toList();
      return Right(MessageWithFilesResult(
          messageId: messageId, serverFileIds: serverFileIds));
    } on DioException catch (e) {
      return Left(NetworkFailure(
          message: e.message ?? 'Failed to create message with files'));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Stream<int> uploadFileDirect({
    required String serverFileId,
    required String localFilePath,
    required String fileType,
  }) async* {
    final ctrl = StreamController<int>();

    dio
        .post(
      '${AppConstants.apiVersion}/files/$serverFileId/upload-bytes',
      data: FormData.fromMap({
        'file': await MultipartFile.fromFile(localFilePath),
      }),
      options: Options(
        sendTimeout: const Duration(minutes: 10),
        receiveTimeout: const Duration(minutes: 2),
      ),
      onSendProgress: (sent, total) {
        if (!ctrl.isClosed && total > 0) {
          ctrl.add((sent * 100 / total).clamp(0, 99).toInt());
        }
      },
    )
        .then((_) {
      if (!ctrl.isClosed) {
        ctrl.add(100);
        ctrl.close();
      }
    }).catchError((dynamic e) {
      if (!ctrl.isClosed) {
        ctrl.addError(e as Object);
        ctrl.close();
      }
    });

    yield* ctrl.stream;
  }

  @override
  Future<Either<Failure, List<ChatMessage>>> getDirectMessages({
    required String userId,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final response = await dio.get(
        '${AppConstants.apiVersion}/messages',
        queryParameters: {
          'userId': userId,
          'page': page,
          'pageSize': pageSize,
        },
      );
      
      final data = response.data as Map<String, dynamic>;
      final messages = (data['messages'] as List)
          .map((m) => _parseMessage(m as Map<String, dynamic>))
          .toList();
      
      return Right(messages);
    } on DioException catch (e) {
      return Left(NetworkFailure(message: e.message ?? 'Failed to load messages'));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, List<ChatMessage>>> getGroupMessages({
    required String groupId,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final response = await dio.get(
        '${AppConstants.apiVersion}/messages',
        queryParameters: {
          'groupId': groupId,
          'page': page,
          'pageSize': pageSize,
        },
      );
      
      final data = response.data as Map<String, dynamic>;
      final messages = (data['messages'] as List)
          .map((m) => _parseMessage(m as Map<String, dynamic>))
          .toList();
      
      return Right(messages);
    } on DioException catch (e) {
      return Left(NetworkFailure(message: e.message ?? 'Failed to load messages'));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
  
  @override
  Future<void> markAsRead(String messageId) async {
    // Implementation would call API to mark message as read
    return Future.value();
  }
  
  ChatMessage _parseMessage(Map<String, dynamic> json) {
    final attachments = (json['attachments'] as List?)
            ?.map((a) => FileAttachment(
                  id: a['id'] as String,
                  messageId: json['id'] as String,
                  fileName: a['fileName'] as String,
                  originalFileName: a['originalFileName'] as String,
                  fileType: a['fileType'] as String,
                  fileExtension: a['fileExtension'] as String,
                  fileSize: a['fileSize'] as int,
                  uploadStatus: _parseUploadStatus(a['uploadStatus'] as String),
                  uploadProgress: a['uploadProgress'] as int? ?? 0,
                  thumbnailUrl: a['thumbnailUrl'] as String?,
                  createdAt: DateTime.parse(json['createdAt'] as String),
                ))
            .toList() ??
        [];
    
    return ChatMessage(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] ?? '',
      receiverId: json['receiverId'] as String?,
      groupId: json['groupId'] as String?,
      textContent: json['textContent'] as String?,
      messageType: _parseMessageType(json['messageType'] as String? ?? 'Text'),
      status: _parseMessageStatus(json['status'] as String? ?? 'Sent'),
      attachments: attachments,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
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
  
  MessageStatus _parseMessageStatus(String status) {
    switch (status.toLowerCase()) {
      case 'sent': return MessageStatus.sent;
      case 'delivered': return MessageStatus.delivered;
      case 'read': return MessageStatus.read;
      case 'deleted': return MessageStatus.deleted;
      default: return MessageStatus.sent;
    }
  }
}
