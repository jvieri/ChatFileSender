class AppConstants {
  // API
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://localhost:5001',
  );
  static const String apiVersion = '/api/v1';
  static const String signalRHubUrl = '/hubs/chat';
  
  // File Upload
  static const int maxFileSize = 100 * 1024 * 1024; // 100 MB
  static const int maxConcurrentUploads = 3;
  static const Duration uploadUrlExpiration = Duration(hours: 1);
  static const Duration downloadUrlExpiration = Duration(hours: 24);
  
  // Allowed file types
  static const Set<String> allowedFileTypes = {
    // Images
    'image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/bmp',
    // Documents
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    // Videos
    'video/mp4', 'video/webm', 'video/quicktime', 'video/x-msvideo',
    // Audio
    'audio/mpeg', 'audio/mp4', 'audio/ogg', 'audio/wav',
    // Archives
    'application/zip', 'application/x-rar-compressed',
    // Text
    'text/plain', 'text/csv',
  };
  
  // Retry
  static const int maxRetries = 3;
  static const Duration baseRetryDelay = Duration(seconds: 10);
  static const Duration maxRetryDelay = Duration(hours: 1);
  
  // Background work
  static const String uploadWorkTag = 'file_upload';
  static const String cleanupWorkTag = 'file_cleanup';
}
