import 'package:flutter/material.dart';
import '../../domain/entities/file_attachment.dart';

class FileAttachmentWidget extends StatelessWidget {
  final FileAttachment attachment;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;
  
  const FileAttachmentWidget({
    super.key,
    required this.attachment,
    this.onTap,
    this.onRetry,
    this.onCancel,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: attachment.uploadStatus == UploadStatus.completed ? onTap : null,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // File preview/icon
            _buildFilePreview(context),
            
            // File info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    attachment.formattedFileSize,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  
                  // Upload progress indicator
                  const SizedBox(height: 8),
                  _buildUploadStatus(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFilePreview(BuildContext context) {
    if (attachment.uploadStatus == UploadStatus.completed) {
      if (attachment.isImage && attachment.thumbnailUrl != null) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: Image.network(
            attachment.thumbnailUrl!,
            height: 150,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFileIcon(),
          ),
        );
      }
    }
    return _buildFileIcon();
  }
  
  Widget _buildFileIcon() {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        color: Color(0xFFE3F2FD),
      ),
      child: Center(
        child: Icon(
          _getFileIcon(),
          size: 48,
          color: _getFileColor(),
        ),
      ),
    );
  }
  
  Widget _buildUploadStatus(BuildContext context) {
    switch (attachment.uploadStatus) {
      case UploadStatus.pending:
        return Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              'Pending...',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const Spacer(),
            if (onCancel != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onCancel,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        );
        
      case UploadStatus.uploading:
        return Column(
          children: [
            LinearProgressIndicator(
              value: attachment.uploadProgress / 100,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${attachment.uploadProgress}%',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Uploading...',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ],
        );
        
      case UploadStatus.processing:
        return Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              'Processing...',
              style: TextStyle(color: Colors.orange[700], fontSize: 12),
            ),
          ],
        );
        
      case UploadStatus.completed:
        return Row(
          children: [
            Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
            const SizedBox(width: 8),
            Text(
              'Ready',
              style: TextStyle(color: Colors.green[700], fontSize: 12),
            ),
          ],
        );
        
      case UploadStatus.failed:
        return Column(
          children: [
            Row(
              children: [
                Icon(Icons.error, size: 16, color: Colors.red[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    attachment.errorMessage ?? 'Upload failed',
                    style: TextStyle(color: Colors.red[700], fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (attachment.canRetry && onRetry != null) ...[
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  minimumSize: Size.zero,
                ),
                child: const Text('Retry', style: TextStyle(fontSize: 12)),
              ),
            ],
          ],
        );
        
      case UploadStatus.uploaded:
      case UploadStatus.cancelled:
        return const SizedBox.shrink();
    }
  }
  
  IconData _getFileIcon() {
    if (attachment.isImage) return Icons.image;
    if (attachment.isVideo) return Icons.videocam;
    if (attachment.fileExtension == 'pdf') return Icons.picture_as_pdf;
    if (['doc', 'docx'].contains(attachment.fileExtension)) return Icons.description;
    if (['xls', 'xlsx'].contains(attachment.fileExtension)) return Icons.table_chart;
    if (['zip', 'rar'].contains(attachment.fileExtension)) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }
  
  Color _getFileColor() {
    if (attachment.isImage) return Colors.blue;
    if (attachment.isVideo) return Colors.purple;
    if (attachment.fileExtension == 'pdf') return Colors.red;
    return Colors.grey;
  }
}
