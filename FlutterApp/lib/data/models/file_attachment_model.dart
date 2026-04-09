import '../../domain/entities/file_attachment.dart';

class FileAttachmentModel {
  final String id;
  final String messageId;
  final String fileName;
  final String originalFileName;
  final String fileType;
  final String fileExtension;
  final int fileSize;
  final String storageKey;
  final String uploadStatus;
  final int uploadProgress;
  final String processingStatus;
  final String? thumbnailUrl;
  final bool isScanned;
  final String? scanStatus;
  final int? width;
  final int? height;
  final int? duration;
  final String? errorMessage;
  final int retryCount;
  final DateTime createdAt;
  final String? localFilePath;
  
  const FileAttachmentModel({
    required this.id,
    required this.messageId,
    required this.fileName,
    required this.originalFileName,
    required this.fileType,
    required this.fileExtension,
    required this.fileSize,
    this.storageKey = '',
    this.uploadStatus = 'Pending',
    this.uploadProgress = 0,
    this.processingStatus = 'Pending',
    this.thumbnailUrl,
    this.isScanned = false,
    this.scanStatus,
    this.width,
    this.height,
    this.duration,
    this.errorMessage,
    this.retryCount = 0,
    required this.createdAt,
    this.localFilePath,
  });
  
  factory FileAttachmentModel.fromJson(Map<String, dynamic> json) {
    return FileAttachmentModel(
      id: json['id'] as String,
      messageId: json['messageId'] as String,
      fileName: json['fileName'] as String,
      originalFileName: json['originalFileName'] as String,
      fileType: json['fileType'] as String,
      fileExtension: json['fileExtension'] as String,
      fileSize: json['fileSize'] as int,
      storageKey: json['storageKey'] ?? '',
      uploadStatus: json['uploadStatus'] ?? 'Pending',
      uploadProgress: json['uploadProgress'] ?? 0,
      processingStatus: json['processingStatus'] ?? 'Pending',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      isScanned: json['isScanned'] ?? false,
      scanStatus: json['scanStatus'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      duration: json['duration'] as int?,
      errorMessage: json['errorMessage'] as String?,
      retryCount: json['retryCount'] ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      localFilePath: json['localFilePath'] as String?,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'messageId': messageId,
      'fileName': fileName,
      'originalFileName': originalFileName,
      'fileType': fileType,
      'fileExtension': fileExtension,
      'fileSize': fileSize,
      'storageKey': storageKey,
      'uploadStatus': uploadStatus,
      'uploadProgress': uploadProgress,
      'processingStatus': processingStatus,
      'thumbnailUrl': thumbnailUrl,
      'isScanned': isScanned,
      'scanStatus': scanStatus,
      'width': width,
      'height': height,
      'duration': duration,
      'errorMessage': errorMessage,
      'retryCount': retryCount,
      'createdAt': createdAt.toIso8601String(),
    };
  }
  
  FileAttachment toEntity() {
    return FileAttachment(
      id: id,
      messageId: messageId,
      fileName: fileName,
      originalFileName: originalFileName,
      fileType: fileType,
      fileExtension: fileExtension,
      fileSize: fileSize,
      storageKey: storageKey,
      uploadStatus: _parseUploadStatus(uploadStatus),
      uploadProgress: uploadProgress,
      processingStatus: _parseProcessingStatus(processingStatus),
      thumbnailUrl: thumbnailUrl,
      isScanned: isScanned,
      scanStatus: scanStatus,
      width: width,
      height: height,
      duration: duration,
      errorMessage: errorMessage,
      retryCount: retryCount,
      createdAt: createdAt,
      localFilePath: localFilePath,
    );
  }
  
  factory FileAttachmentModel.fromEntity(FileAttachment entity) {
    return FileAttachmentModel(
      id: entity.id,
      messageId: entity.messageId,
      fileName: entity.fileName,
      originalFileName: entity.originalFileName,
      fileType: entity.fileType,
      fileExtension: entity.fileExtension,
      fileSize: entity.fileSize,
      storageKey: entity.storageKey,
      uploadStatus: entity.uploadStatus.name,
      uploadProgress: entity.uploadProgress,
      processingStatus: entity.processingStatus.name,
      thumbnailUrl: entity.thumbnailUrl,
      isScanned: entity.isScanned,
      scanStatus: entity.scanStatus,
      width: entity.width,
      height: entity.height,
      duration: entity.duration,
      errorMessage: entity.errorMessage,
      retryCount: entity.retryCount,
      createdAt: entity.createdAt,
      localFilePath: entity.localFilePath,
    );
  }
  
  static UploadStatus _parseUploadStatus(String status) {
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
  
  static ProcessingStatus _parseProcessingStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return ProcessingStatus.pending;
      case 'inprogress': return ProcessingStatus.inProgress;
      case 'completed': return ProcessingStatus.completed;
      case 'failed': return ProcessingStatus.failed;
      case 'skipped': return ProcessingStatus.skipped;
      default: return ProcessingStatus.pending;
    }
  }
}
