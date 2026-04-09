import 'dart:io';
import 'package:dio/dio.dart';
import '../../domain/repositories/file_upload_repository.dart';
import '../../domain/repositories/local_data_source.dart';
import '../datasources/file_upload_remote_data_source.dart';
import '../../core/use_result.dart';

class FileUploadRepositoryImpl implements FileUploadRepository {
  final FileUploadRemoteDataSource remoteDataSource;
  final LocalDataSource localDataSource;
  final Dio dio;
  
  FileUploadRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.dio,
  });
  
  @override
  Future<Either<Failure, UploadSession>> createUploadSession({
    required String messageId,
    required String fileName,
    required int fileSize,
    required String fileType,
  }) async {
    try {
      final session = await remoteDataSource.createUploadSession(
        messageId: messageId,
        fileName: fileName,
        fileSize: fileSize,
        fileType: fileType,
      );
      return Right(session);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, void>> uploadFile({
    required UploadSession session,
    required String localFilePath,
    Function(int progress)? onProgress,
  }) async {
    try {
      final file = File(localFilePath);
      if (!await file.exists()) {
        return Left(ServerFailure(message: 'File not found: $localFilePath'));
      }
      
      final fileSize = await file.length();
      
      // Upload directly to storage using presigned URL
      await dio.put(
        session.uploadUrl,
        data: file.openRead(),
        options: Options(
          headers: {
            'Content-Length': fileSize,
            'Content-Type': 'application/octet-stream',
          },
        ),
        onSendProgress: (sent, total) {
          final progress = total > 0 ? ((sent / total) * 100).toInt() : 0;
          onProgress?.call(progress);
        },
      );
      
      return const Right(null);
    } on DioException catch (e) {
      return Left(NetworkFailure(message: e.message ?? 'Upload failed'));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, void>> confirmUpload(String fileId) async {
    try {
      await remoteDataSource.confirmUpload(fileId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, String>> getDownloadUrl(String fileId) async {
    try {
      final url = await remoteDataSource.getDownloadUrl(fileId);
      return Right(url);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, void>> retryUpload(String fileId) async {
    try {
      await remoteDataSource.retryUpload(fileId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, void>> cancelUpload(String fileId) async {
    // Cancel is handled by the upload service
    return const Right(null);
  }
}
