import '../../core/use_result.dart';
import '../repositories/file_upload_repository.dart';

class ConfirmUpload {
  final FileUploadRepository repository;
  
  ConfirmUpload(this.repository);
  
  Future<Either<Failure, void>> call(String fileId) async {
    try {
      return await repository.confirmUpload(fileId);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
