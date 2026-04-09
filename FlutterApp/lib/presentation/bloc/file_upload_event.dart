part of 'file_upload_bloc.dart';

abstract class FileUploadEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class SelectFileEvent extends FileUploadEvent {}
class RemoveFileEvent extends FileUploadEvent {
  final String fileId;
  RemoveFileEvent(this.fileId);
  @override
  List<Object?> get props => [fileId];
}
class StartUploadEvent extends FileUploadEvent {
  final String messageId;
  StartUploadEvent(this.messageId);
  @override
  List<Object?> get props => [messageId];
}
class UploadProgressEvent extends FileUploadEvent {
  final String fileId;
  final int progress;
  final UploadStatus status;
  UploadProgressEvent(this.fileId, this.progress, this.status);
  @override
  List<Object?> get props => [fileId, progress, status];
}
class UploadCompletedEvent extends FileUploadEvent {
  final String fileId;
  final FileAttachment file;
  UploadCompletedEvent(this.fileId, this.file);
  @override
  List<Object?> get props => [fileId, file];
}
class UploadFailedEvent extends FileUploadEvent {
  final String fileId;
  final String errorMessage;
  UploadFailedEvent(this.fileId, this.errorMessage);
  @override
  List<Object?> get props => [fileId, errorMessage];
}
class RetryUploadEvent extends FileUploadEvent {
  final String fileId;
  RetryUploadEvent(this.fileId);
  @override
  List<Object?> get props => [fileId];
}
class CancelUploadEvent extends FileUploadEvent {
  final String fileId;
  CancelUploadEvent(this.fileId);
  @override
  List<Object?> get props => [fileId];
}
class LoadPendingUploadsEvent extends FileUploadEvent {}
