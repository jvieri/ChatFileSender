part of 'chat_bloc.dart';

abstract class ChatEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadMessagesEvent extends ChatEvent {
  final String? userId;
  final String? groupId;
  LoadMessagesEvent({this.userId, this.groupId});
  @override
  List<Object?> get props => [userId, groupId];
}

class LoadMoreMessagesEvent extends ChatEvent {}

class SendMessageEvent extends ChatEvent {
  final String textContent;
  SendMessageEvent(this.textContent);
  @override
  List<Object?> get props => [textContent];
}

class SendFileMessageEvent extends ChatEvent {
  final String? textContent;
  final List<FileAttachment> attachments;
  SendFileMessageEvent({this.textContent, required this.attachments});
  @override
  List<Object?> get props => [textContent, attachments];
}

class ReceiveMessageEvent extends ChatEvent {
  final ChatMessage message;
  ReceiveMessageEvent(this.message);
  @override
  List<Object?> get props => [message];
}

class UpdateFileProgressEvent extends ChatEvent {
  final String fileId;
  final int progress;
  final UploadStatus status;
  UpdateFileProgressEvent(this.fileId, this.progress, this.status);
  @override
  List<Object?> get props => [fileId, progress, status];
}

class UpdateFileCompletedEvent extends ChatEvent {
  final String fileId;
  UpdateFileCompletedEvent(this.fileId);
  @override
  List<Object?> get props => [fileId];
}

class UpdateFileErrorEvent extends ChatEvent {
  final String fileId;
  final String errorMessage;
  UpdateFileErrorEvent(this.fileId, this.errorMessage);
  @override
  List<Object?> get props => [fileId, errorMessage];
}

class JoinChatEvent extends ChatEvent {
  final String chatId;
  JoinChatEvent(this.chatId);
  @override
  List<Object?> get props => [chatId];
}

class LeaveChatEvent extends ChatEvent {
  final String chatId;
  LeaveChatEvent(this.chatId);
  @override
  List<Object?> get props => [chatId];
}

class SimulateReceiveMessageEvent extends ChatEvent {
  final String senderId;
  final String senderName;
  final String textContent;
  SimulateReceiveMessageEvent({
    required this.senderId,
    required this.senderName,
    required this.textContent,
  });
  @override
  List<Object?> get props => [senderId, senderName, textContent];
}
