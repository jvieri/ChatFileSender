import 'package:equatable/equatable.dart';
import '../entities/file_attachment.dart';

enum MessageType { text, file, image, video, system }
enum MessageStatus { sent, delivered, read, deleted }

class ChatMessage extends Equatable {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String? receiverId;
  final String? groupId;
  final String? textContent;
  final MessageType messageType;
  final MessageStatus status;
  final List<FileAttachment> attachments;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  const ChatMessage({
    required this.id,
    required this.senderId,
    this.senderName = '',
    this.senderAvatar,
    this.receiverId,
    this.groupId,
    this.textContent,
    this.messageType = MessageType.text,
    this.status = MessageStatus.sent,
    this.attachments = const [],
    required this.createdAt,
    this.updatedAt,
  });
  
  bool get isGroupMessage => groupId != null;
  bool get hasAttachments => attachments.isNotEmpty;
  bool get isMine => senderId == currentUserId;
  
  static String currentUserId = '';
  
  ChatMessage copyWith({
    MessageStatus? status,
    List<FileAttachment>? attachments,
    String? textContent,
  }) {
    return ChatMessage(
      id: id,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      receiverId: receiverId,
      groupId: groupId,
      textContent: textContent ?? this.textContent,
      messageType: messageType,
      status: status ?? this.status,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
  
  @override
  List<Object?> get props => [id, senderId, messageType, status, createdAt];
}
