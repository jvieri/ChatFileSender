import '../../core/use_result.dart';
import '../repositories/file_upload_repository.dart';

class CreateMessageWithFile {
  final FileUploadRepository repository;
  
  CreateMessageWithFile(this.repository);
  
  Future<Either<Failure, UploadResult>> call({
    required String? receiverId,
    required String? groupId,
    required String? textContent,
    required List<UploadFileInfo> files,
  }) async {
    // Validate files
    for (final file in files) {
      if (file.size > 100 * 1024 * 1024) {
        return Left(const FileTooLargeFailure());
      }
      
      // Validation would check against allowed types
    }
    
    try {
      // Create upload sessions for all files
      final sessions = <UploadSession>[];
      for (final file in files) {
        final result = await repository.createUploadSession(
          messageId: 'pending',
          fileName: file.name,
          fileSize: file.size,
          fileType: file.mimeType,
        );
        
        result.fold(
          (failure) => Left(failure),
          (session) => sessions.add(session),
        );
      }
      
      return Right(UploadResult(sessions: sessions));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}

class UploadResult {
  final List<UploadSession> sessions;
  const UploadResult({required this.sessions});
}

class UploadFileInfo {
  final String path;
  final String name;
  final int size;
  final String mimeType;
  
  const UploadFileInfo({
    required this.path,
    required this.name,
    required this.size,
    required this.mimeType,
  });
}
