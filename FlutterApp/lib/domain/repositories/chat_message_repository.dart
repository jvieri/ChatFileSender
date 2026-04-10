import '../entities/chat_message.dart';
import '../entities/file_attachment.dart';
import '../../core/use_result.dart';

class MessageWithFilesResult {
  final String messageId;
  final List<String> serverFileIds; // parallel index matches the files list
  const MessageWithFilesResult({required this.messageId, required this.serverFileIds});
}

abstract class ChatMessageRepository {
  Future<Either<Failure, ChatMessage>> sendMessage({
    String? receiverId,
    String? groupId,
    String? textContent,
  });

  Future<Either<Failure, MessageWithFilesResult>> createMessageWithFiles({
    String? receiverId,
    String? groupId,
    String? textContent,
    required List<FileAttachment> files,
  });

  /// Uploads a file directly to the backend API.
  /// Yields progress values 0–100.
  Stream<int> uploadFileDirect({
    required String serverFileId,
    required String localFilePath,
    required String fileType,
  });

  Future<Either<Failure, List<ChatMessage>>> getDirectMessages({
    required String userId,
    int page = 1,
    int pageSize = 50,
  });

  Future<Either<Failure, List<ChatMessage>>> getGroupMessages({
    required String groupId,
    int page = 1,
    int pageSize = 50,
  });

  Future<void> markAsRead(String messageId);
}
