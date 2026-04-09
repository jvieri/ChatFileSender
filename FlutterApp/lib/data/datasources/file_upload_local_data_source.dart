import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import '../local/app_database.dart';
import '../../domain/entities/file_attachment.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/local_data_source.dart';

class LocalDataSourceImpl implements LocalDataSource {
  final AppDatabase database;
  
  LocalDataSourceImpl(this.database);
  
  @override
  Future<void> savePendingUpload(FileAttachment attachment) async {
    await database.insertPendingUpload(
      PendingUploadsCompanion.insert(
        fileId: attachment.id,
        messageId: attachment.messageId,
        localFilePath: attachment.localFilePath ?? '',
        fileName: attachment.fileName,
        fileSize: attachment.fileSize,
        fileType: attachment.fileType,
        uploadStatus: attachment.uploadStatus.name,
        uploadProgress: attachment.uploadProgress,
        retryCount: attachment.retryCount,
        createdAt: attachment.createdAt.millisecondsSinceEpoch,
        errorMessage: attachment.errorMessage != null
            ? Value(attachment.errorMessage!)
            : const Value.absent(),
      ),
    );
  }
  
  @override
  Future<List<FileAttachment>> getPendingUploads() async {
    final rows = await database.getAllPendingUploads();
    return rows.map((row) {
      return FileAttachment(
        id: row.fileId,
        messageId: row.messageId,
        fileName: row.fileName,
        originalFileName: row.fileName,
        fileType: row.fileType,
        fileExtension: row.fileType.split('/').last,
        fileSize: row.fileSize,
        uploadStatus: _parseUploadStatus(row.uploadStatus),
        uploadProgress: row.uploadProgress,
        retryCount: row.retryCount,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
        localFilePath: row.localFilePath,
        errorMessage: row.errorMessage,
      );
    }).toList();
  }
  
  @override
  Future<void> updatePendingUpload(FileAttachment attachment) async {
    await database.updatePendingUpload(
      PendingUploadsCompanion(
        fileId: Value(attachment.id),
        uploadStatus: Value(attachment.uploadStatus.name),
        uploadProgress: Value(attachment.uploadProgress),
        retryCount: Value(attachment.retryCount),
        errorMessage: attachment.errorMessage != null
            ? Value(attachment.errorMessage!)
            : const Value.absent(),
      ),
    );
  }
  
  @override
  Future<void> deletePendingUpload(String fileId) async {
    await database.deletePendingUpload(fileId);
  }
  
  @override
  Future<void> cacheMessage(ChatMessage message) async {
    await database.insertMessage(
      CachedMessagesCompanion.insert(
        id: message.id,
        senderId: message.senderId,
        senderName: Value<String?>(message.senderName.isEmpty ? null : message.senderName),
        receiverId: message.receiverId != null ? Value(message.receiverId!) : const Value.absent(),
        groupId: message.groupId != null ? Value(message.groupId!) : const Value.absent(),
        textContent: message.textContent != null ? Value(message.textContent!) : const Value.absent(),
        messageType: message.messageType.name,
        status: message.status.name,
        createdAt: message.createdAt.millisecondsSinceEpoch,
      ),
    );
  }
  
  @override
  Future<List<ChatMessage>> getCachedMessages(String chatId) async {
    final rows = await database.getMessagesForChat(chatId);
    return rows.map((row) {
      return ChatMessage(
        id: row.id,
        senderId: row.senderId,
        senderName: row.senderName ?? '',
        receiverId: row.receiverId,
        groupId: row.groupId,
        textContent: row.textContent,
        messageType: _parseMessageType(row.messageType),
        status: _parseMessageStatus(row.status),
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      );
    }).toList();
  }
  
  @override
  Future<void> deleteCachedMessage(String messageId) async {
    await database.deleteMessage(messageId);
  }
  
  @override
  Future<void> saveUploadState(String fileId, Map<String, dynamic> state) async {
    await database.saveUploadState(fileId, jsonEncode(state));
  }
  
  @override
  Future<Map<String, dynamic>?> getUploadState(String fileId) async {
    final row = await database.getUploadState(fileId);
    if (row == null) return null;
    return jsonDecode(row.state) as Map<String, dynamic>;
  }
  
  @override
  Future<void> clearUploadState(String fileId) async {
    await database.deleteUploadState(fileId);
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
