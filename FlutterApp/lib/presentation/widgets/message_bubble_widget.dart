import 'package:flutter/material.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_message_repository.dart';
import 'file_attachment_widget.dart';

class MessageBubbleWidget extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onFileTap;
  final ChatMessageRepository? repository;

  const MessageBubbleWidget({
    super.key,
    required this.message,
    this.onFileTap,
    this.repository,
  });
  
  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        constraints: const BoxConstraints(maxWidth: 300),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMine ? Colors.blue[100] : Colors.grey[200],
                borderRadius: BorderRadius.circular(12).copyWith(
                  bottomRight: isMine ? const Radius.circular(0) : const Radius.circular(12),
                  bottomLeft: isMine ? const Radius.circular(12) : const Radius.circular(0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender name (for group chats or incoming messages)
                  if (!isMine && message.senderName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.senderName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getSenderColor(message.senderId),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  
                  // Text content
                  if (message.textContent != null && message.textContent!.isNotEmpty)
                    Text(
                      message.textContent!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  
                  // File attachments
                  if (message.hasAttachments) ...[
                    if (message.textContent != null && message.textContent!.isNotEmpty)
                      const SizedBox(height: 8),
                    ...message.attachments.map<Widget>((attachment) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: FileAttachmentWidget(
                          attachment: attachment,
                          onTap: onFileTap,
                          onRetry: attachment.canRetry ? () {
                            // Retry upload - would trigger BLoC event
                          } : null,
                          repository: repository,
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
            
            // Timestamp and status
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 10,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.status.index >= 2 ? Icons.done_all : Icons.done,
                      size: 14,
                      color: message.status.index >= 2 ? Colors.blue : Colors.grey,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getSenderColor(String senderId) {
    // Generate a consistent color based on sender ID
    final hash = senderId.hashCode;
    final colors = [
      Colors.purple,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.teal,
      Colors.red,
      Colors.indigo,
    ];
    return colors[hash.abs() % colors.length];
  }
  
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }
}
