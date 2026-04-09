part of 'file_upload_bloc.dart';

class FileUploadState extends Equatable {
  final bool isLoading;
  final bool isUploading;
  final String? errorMessage;
  final List<FileAttachment> selectedFiles;
  final List<FileAttachment> activeUploads;
  final List<FileAttachment> completedFiles;
  final List<FileAttachment> failedUploads;
  
  const FileUploadState({
    this.isLoading = false,
    this.isUploading = false,
    this.errorMessage,
    this.selectedFiles = const [],
    this.activeUploads = const [],
    this.completedFiles = const [],
    this.failedUploads = const [],
  });
  
  FileUploadState copyWith({
    bool? isLoading,
    bool? isUploading,
    String? errorMessage,
    List<FileAttachment>? selectedFiles,
    List<FileAttachment>? activeUploads,
    List<FileAttachment>? completedFiles,
    List<FileAttachment>? failedUploads,
  }) {
    return FileUploadState(
      isLoading: isLoading ?? this.isLoading,
      isUploading: isUploading ?? this.isUploading,
      errorMessage: errorMessage,
      selectedFiles: selectedFiles ?? this.selectedFiles,
      activeUploads: activeUploads ?? this.activeUploads,
      completedFiles: completedFiles ?? this.completedFiles,
      failedUploads: failedUploads ?? this.failedUploads,
    );
  }
  
  int get totalProgress {
    if (activeUploads.isEmpty) return 0;
    return (activeUploads.fold<int>(0, (sum, f) => sum + f.uploadProgress) / 
            activeUploads.length)
        .toInt();
  }
  
  bool get hasFiles => selectedFiles.isNotEmpty || activeUploads.isNotEmpty;
  
  @override
  List<Object?> get props => [
        isLoading,
        isUploading,
        errorMessage,
        selectedFiles,
        activeUploads,
        completedFiles,
        failedUploads,
      ];
}
