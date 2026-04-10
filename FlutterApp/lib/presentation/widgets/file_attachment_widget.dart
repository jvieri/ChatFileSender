import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/entities/file_attachment.dart';
import '../../domain/repositories/chat_message_repository.dart';

enum _DownloadState { idle, downloading, done, error }

class FileAttachmentWidget extends StatefulWidget {
  final FileAttachment attachment;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;
  final ChatMessageRepository? repository;

  const FileAttachmentWidget({
    super.key,
    required this.attachment,
    this.onTap,
    this.onRetry,
    this.onCancel,
    this.repository,
  });

  @override
  State<FileAttachmentWidget> createState() => _FileAttachmentWidgetState();
}

class _FileAttachmentWidgetState extends State<FileAttachmentWidget> {
  _DownloadState _dlState = _DownloadState.idle;
  int _dlProgress = 0;
  StreamSubscription<int>? _dlSub;

  @override
  void dispose() {
    _dlSub?.cancel();
    super.dispose();
  }

  void _startDownload() {
    if (widget.repository == null) return;
    setState(() {
      _dlState = _DownloadState.downloading;
      _dlProgress = 0;
    });

    _dlSub = widget.repository!
        .downloadFile(
          fileId: widget.attachment.id,
          fileName: widget.attachment.fileName,
        )
        .listen(
          (progress) {
            if (mounted) setState(() => _dlProgress = progress);
          },
          onDone: () {
            if (mounted) setState(() => _dlState = _DownloadState.done);
          },
          onError: (_) {
            if (mounted) setState(() => _dlState = _DownloadState.error);
          },
          cancelOnError: true,
        );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.attachment.uploadStatus == UploadStatus.completed
          ? widget.onTap
          : null,
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
            _buildFilePreview(context),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.attachment.fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.attachment.formattedFileSize,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
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
    if (widget.attachment.uploadStatus == UploadStatus.completed) {
      if (widget.attachment.isImage &&
          widget.attachment.thumbnailUrl != null) {
        return ClipRRect(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(12)),
          child: Image.network(
            widget.attachment.thumbnailUrl!,
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
    switch (widget.attachment.uploadStatus) {
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
            if (widget.onCancel != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: widget.onCancel,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        );

      case UploadStatus.uploading:
        return Column(
          children: [
            LinearProgressIndicator(
              value: widget.attachment.uploadProgress / 100,
              backgroundColor: Colors.grey[300],
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.attachment.uploadProgress}%',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Uploading...',
                  style:
                      TextStyle(color: Colors.grey[600], fontSize: 12),
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
              style:
                  TextStyle(color: Colors.orange[700], fontSize: 12),
            ),
          ],
        );

      case UploadStatus.completed:
        return _buildDownloadArea();

      case UploadStatus.uploaded:
        return _buildDownloadArea();

      case UploadStatus.failed:
        return Column(
          children: [
            Row(
              children: [
                Icon(Icons.error, size: 16, color: Colors.red[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.attachment.errorMessage ?? 'Upload failed',
                    style:
                        TextStyle(color: Colors.red[700], fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (widget.attachment.canRetry && widget.onRetry != null) ...[
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: widget.onRetry,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  minimumSize: Size.zero,
                ),
                child:
                    const Text('Retry', style: TextStyle(fontSize: 12)),
              ),
            ],
          ],
        );

      case UploadStatus.cancelled:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDownloadArea() {
    switch (_dlState) {
      case _DownloadState.idle:
        return Row(
          children: [
            Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
            const SizedBox(width: 8),
            Text(
              'Ready',
              style: TextStyle(color: Colors.green[700], fontSize: 12),
            ),
            const Spacer(),
            if (widget.repository != null)
              IconButton(
                icon: const Icon(Icons.download, size: 20),
                color: Colors.blue[700],
                onPressed: _startDownload,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Download',
              ),
          ],
        );

      case _DownloadState.downloading:
        return Column(
          children: [
            LinearProgressIndicator(
              value: _dlProgress / 100,
              backgroundColor: Colors.grey[300],
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$_dlProgress%',
                    style: const TextStyle(fontSize: 12)),
                Text(
                  'Downloading...',
                  style:
                      TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ],
        );

      case _DownloadState.done:
        return Row(
          children: [
            Icon(Icons.download_done, size: 16, color: Colors.green[700]),
            const SizedBox(width: 8),
            Text(
              'Saved',
              style: TextStyle(color: Colors.green[700], fontSize: 12),
            ),
          ],
        );

      case _DownloadState.error:
        return Row(
          children: [
            Icon(Icons.error_outline, size: 16, color: Colors.red[700]),
            const SizedBox(width: 8),
            Text(
              'Download failed',
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              color: Colors.blue[700],
              onPressed: _startDownload,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Retry download',
            ),
          ],
        );
    }
  }

  IconData _getFileIcon() {
    if (widget.attachment.isImage) return Icons.image;
    if (widget.attachment.isVideo) return Icons.videocam;
    if (widget.attachment.fileExtension == 'pdf')
      return Icons.picture_as_pdf;
    if (['doc', 'docx'].contains(widget.attachment.fileExtension))
      return Icons.description;
    if (['xls', 'xlsx'].contains(widget.attachment.fileExtension))
      return Icons.table_chart;
    if (['zip', 'rar'].contains(widget.attachment.fileExtension))
      return Icons.folder_zip;
    return Icons.insert_drive_file;
  }

  Color _getFileColor() {
    if (widget.attachment.isImage) return Colors.blue;
    if (widget.attachment.isVideo) return Colors.purple;
    if (widget.attachment.fileExtension == 'pdf') return Colors.red;
    return Colors.grey;
  }
}
