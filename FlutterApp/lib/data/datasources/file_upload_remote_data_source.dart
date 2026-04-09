import 'package:dio/dio.dart';
import '../../core/constants.dart';
import '../../domain/repositories/file_upload_repository.dart';

class FileUploadRemoteDataSource {
  final Dio dio;
  
  FileUploadRemoteDataSource(this.dio);
  
  Future<UploadSession> createUploadSession({
    required String messageId,
    required String fileName,
    required int fileSize,
    required String fileType,
    String? receiverId,
    String? groupId,
    String? textContent,
  }) async {
    try {
      final response = await dio.post(
        '${AppConstants.baseUrl}${AppConstants.apiVersion}/messages/with-file',
        data: {
          'receiverId': receiverId,
          'groupId': groupId,
          'textContent': textContent,
          'files': [
            {
              'fileName': fileName,
              'fileSize': fileSize,
              'fileType': fileType,
            }
          ],
        },
      );
      
      final data = response.data as Map<String, dynamic>;
      final uploadUrls = data['uploadUrls'] as List;
      final uploadUrlData = uploadUrls.first as Map<String, dynamic>;
      
      return UploadSession(
        fileId: uploadUrlData['fileId'] as String,
        uploadUrl: uploadUrlData['uploadUrl'] as String,
        expiresAt: DateTime.parse(uploadUrlData['expiresAt'] as String),
      );
    } on DioException catch (e) {
      throw Exception('Failed to create upload session: ${e.response?.data ?? e.message}');
    }
  }
  
  Future<void> confirmUpload(String fileId) async {
    try {
      await dio.post(
        '${AppConstants.baseUrl}${AppConstants.apiVersion}/files/$fileId/confirm',
        data: {},
      );
    } on DioException catch (e) {
      throw Exception('Failed to confirm upload: ${e.response?.data ?? e.message}');
    }
  }
  
  Future<String> getDownloadUrl(String fileId) async {
    try {
      final response = await dio.get(
        '${AppConstants.baseUrl}${AppConstants.apiVersion}/files/$fileId/download-url',
      );
      
      final data = response.data as Map<String, dynamic>;
      return data['downloadUrl'] as String;
    } on DioException catch (e) {
      throw Exception('Failed to get download URL: ${e.response?.data ?? e.message}');
    }
  }
  
  Future<void> retryUpload(String fileId) async {
    try {
      await dio.post(
        '${AppConstants.baseUrl}${AppConstants.apiVersion}/files/$fileId/retry',
      );
    } on DioException catch (e) {
      throw Exception('Failed to retry upload: ${e.response?.data ?? e.message}');
    }
  }
}
