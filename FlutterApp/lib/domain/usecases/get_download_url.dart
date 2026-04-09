import '../../core/use_result.dart';
import '../repositories/file_upload_repository.dart';

class GetDownloadUrl {
  final FileUploadRepository repository;
  
  GetDownloadUrl(this.repository);
  
  Future<Either<Failure, String>> call(String fileId) async {
    try {
      return await repository.getDownloadUrl(fileId);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
