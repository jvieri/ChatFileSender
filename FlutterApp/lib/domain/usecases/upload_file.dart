import 'dart:async';
import '../../core/use_result.dart';
import '../repositories/file_upload_repository.dart';

class UploadFile {
  final FileUploadRepository repository;
  
  UploadFile(this.repository);
  
  Future<Either<Failure, void>> call({
    required UploadSession session,
    required String localFilePath,
    Function(int progress)? onProgress,
  }) async {
    if (session.isExpired) {
      return Left(ServerFailure(message: 'Upload URL has expired'));
    }
    
    try {
      return await repository.uploadFile(
        session: session,
        localFilePath: localFilePath,
        onProgress: onProgress,
      );
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
