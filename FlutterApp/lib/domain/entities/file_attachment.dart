import 'package:equatable/equatable.dart';

enum UploadStatus {
  pending,
  uploading,
  uploaded,
  processing,
  completed,
  failed,
  cancelled
}

enum ProcessingStatus {
  pending,
  inProgress,
  completed,
  failed,
  skipped
}

class FileAttachment extends Equatable {
  final String id;
  final String messageId;
  final String fileName;
  final String originalFileName;
  final String fileType;
  final String fileExtension;
  final int fileSize;
  final String storageKey;
  final UploadStatus uploadStatus;
  final int uploadProgress;
  final ProcessingStatus processingStatus;
  final String? thumbnailUrl;
  final bool isScanned;
  final String? scanStatus;
  final int? width;
  final int? height;
  final int? duration;
  final String? errorMessage;
  final int retryCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? localFilePath; // For offline support
  
  const FileAttachment({
    required this.id,
    required this.messageId,
    required this.fileName,
    required this.originalFileName,
    required this.fileType,
    required this.fileExtension,
    required this.fileSize,
    this.storageKey = '',
    this.uploadStatus = UploadStatus.pending,
    this.uploadProgress = 0,
    this.processingStatus = ProcessingStatus.pending,
    this.thumbnailUrl,
    this.isScanned = false,
    this.scanStatus,
    this.width,
    this.height,
    this.duration,
    this.errorMessage,
    this.retryCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.localFilePath,
  });
  
  FileAttachment copyWith({
    UploadStatus? uploadStatus,
    int? uploadProgress,
    ProcessingStatus? processingStatus,
    String? thumbnailUrl,
    String? errorMessage,
    int? retryCount,
    String? storageKey,
    String? localFilePath,
  }) {
    return FileAttachment(
      id: id,
      messageId: messageId,
      fileName: fileName,
      originalFileName: originalFileName,
      fileType: fileType,
      fileExtension: fileExtension,
      fileSize: fileSize,
      storageKey: storageKey ?? this.storageKey,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      processingStatus: processingStatus ?? this.processingStatus,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isScanned: isScanned,
      scanStatus: scanStatus,
      width: width,
      height: height,
      duration: duration,
      errorMessage: errorMessage ?? this.errorMessage,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      localFilePath: localFilePath ?? this.localFilePath,
    );
  }
  
  bool get isImage => fileType.startsWith('image/');
  bool get isVideo => fileType.startsWith('video/');
  bool get isDocument => fileType.startsWith('application/') || 
                         fileType.startsWith('text/');
  bool get canRetry => retryCount < 3 && uploadStatus == UploadStatus.failed;
  
  String get formattedFileSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  
  @override
  List<Object?> get props => [id, messageId, fileName, uploadStatus, uploadProgress];
}
