import '../entities/chat_message.dart';
import '../../core/use_result.dart';

abstract class ChatMessageRepository {
  Future<Either<Failure, ChatMessage>> sendMessage({
    String? receiverId,
    String? groupId,
    String? textContent,
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
