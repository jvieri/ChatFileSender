import '../../core/use_result.dart';

abstract class FileUploadRepository {
  Future<Either<Failure, UploadSession>> createUploadSession({
    required String messageId,
    required String fileName,
    required int fileSize,
    required String fileType,
  });
  
  Future<Either<Failure, void>> uploadFile({
    required UploadSession session,
    required String localFilePath,
    Function(int progress)? onProgress,
  });
  
  Future<Either<Failure, void>> confirmUpload(String fileId);
  Future<Either<Failure, String>> getDownloadUrl(String fileId);
  Future<Either<Failure, void>> retryUpload(String fileId);
  Future<Either<Failure, void>> cancelUpload(String fileId);
}

class UploadSession {
  final String fileId;
  final String uploadUrl;
  final DateTime expiresAt;
  
  const UploadSession({
    required this.fileId,
    required this.uploadUrl,
    required this.expiresAt,
  });
  
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
