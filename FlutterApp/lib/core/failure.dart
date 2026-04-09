import 'package:equatable/equatable.dart';

class Failure extends Equatable {
  final String message;
  final String? code;
  final int? statusCode;
  
  const Failure({
    required this.message,
    this.code,
    this.statusCode,
  });
  
  @override
  List<Object?> get props => [message, code, statusCode];
}

// Specific failure types
class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'Network connection failed'})
      : super(code: 'NETWORK_ERROR');
}

class ServerFailure extends Failure {
  const ServerFailure({super.message = 'Server error occurred', super.statusCode});
}

class FileTooLargeFailure extends Failure {
  const FileTooLargeFailure({super.message = 'File exceeds maximum size limit'});
}

class InvalidFileTypeFailure extends Failure {
  const InvalidFileTypeFailure({super.message = 'File type not allowed'});
}

class UploadCancelledFailure extends Failure {
  const UploadCancelledFailure({super.message = 'Upload was cancelled'});
}

class OfflineFailure extends Failure {
  const OfflineFailure({super.message = 'No internet connection'});
}
