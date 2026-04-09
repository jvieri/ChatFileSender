import '../entities/file_attachment.dart';
import '../entities/chat_message.dart';

abstract class LocalDataSource {
  // Pending uploads
  Future<void> savePendingUpload(FileAttachment attachment);
  Future<List<FileAttachment>> getPendingUploads();
  Future<void> updatePendingUpload(FileAttachment attachment);
  Future<void> deletePendingUpload(String fileId);
  
  // Messages cache
  Future<void> cacheMessage(ChatMessage message);
  Future<List<ChatMessage>> getCachedMessages(String chatId);
  Future<void> deleteCachedMessage(String messageId);
  
  // Upload state
  Future<void> saveUploadState(String fileId, Map<String, dynamic> state);
  Future<Map<String, dynamic>?> getUploadState(String fileId);
  Future<void> clearUploadState(String fileId);
}
