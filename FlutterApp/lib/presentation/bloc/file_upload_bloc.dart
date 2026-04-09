import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import '../../core/constants.dart';
import '../../domain/entities/file_attachment.dart';
import '../../domain/repositories/file_upload_repository.dart';
import '../../domain/repositories/local_data_source.dart';
import '../../services/upload_manager.dart';

part 'file_upload_event.dart';
part 'file_upload_state.dart';

class FileUploadBloc extends Bloc<FileUploadEvent, FileUploadState> {
  final LocalDataSource _localDataSource;
  final UploadManager _uploadManager;

  FileUploadBloc({
    required FileUploadRepository uploadRepository,
    required LocalDataSource localDataSource,
    required UploadManager uploadManager,
  })  : _localDataSource = localDataSource,
        _uploadManager = uploadManager,
        super(const FileUploadState()) {
    on<SelectFileEvent>(_onSelectFile);
    on<RemoveFileEvent>(_onRemoveFile);
    on<StartUploadEvent>(_onStartUpload);
    on<UploadProgressEvent>(_onUploadProgress);
    on<UploadCompletedEvent>(_onUploadCompleted);
    on<UploadFailedEvent>(_onUploadFailed);
    on<RetryUploadEvent>(_onRetryUpload);
    on<CancelUploadEvent>(_onCancelUpload);
    on<LoadPendingUploadsEvent>(_onLoadPendingUploads);
  }
  
  Future<void> _onSelectFile(
    SelectFileEvent event,
    Emitter<FileUploadState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp',
          'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
          'mp4', 'webm', 'mov', 'avi',
          'mp3', 'ogg', 'wav',
          'zip', 'rar',
          'txt', 'csv',
        ],
      );
      
      if (result == null || result.files.isEmpty) {
        emit(state.copyWith(isLoading: false));
        return;
      }
      
      final selectedFiles = <FileAttachment>[];
      
      for (final file in result.files) {
        if (file.path == null) continue;
        
        final filePath = file.path!;
        final fileSize = await File(filePath).length();
        
        // Validate file size
        if (fileSize > AppConstants.maxFileSize) {
          emit(state.copyWith(
            isLoading: false,
            errorMessage: 'File "${file.name}" exceeds 100 MB limit',
          ));
          return;
        }
        
        // Validate file type
        final mimeType = lookupMimeType(filePath) ?? '';
        if (!AppConstants.allowedFileTypes.contains(mimeType)) {
          emit(state.copyWith(
            isLoading: false,
            errorMessage: 'File type "${file.name}" is not allowed',
          ));
          return;
        }
        
        final attachment = FileAttachment(
          id: UniqueKey().toString(),
          messageId: '',
          fileName: file.name,
          originalFileName: file.name,
          fileType: mimeType,
          fileExtension: file.extension ?? '',
          fileSize: fileSize,
          uploadStatus: UploadStatus.pending,
          uploadProgress: 0,
          createdAt: DateTime.now(),
          localFilePath: filePath,
        );
        
        selectedFiles.add(attachment);
      }
      
      emit(state.copyWith(
        isLoading: false,
        selectedFiles: [...state.selectedFiles, ...selectedFiles],
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to select file: $e',
      ));
    }
  }
  
  void _onRemoveFile(
    RemoveFileEvent event,
    Emitter<FileUploadState> emit,
  ) {
    emit(state.copyWith(
      selectedFiles: state.selectedFiles
          .where((f) => f.id != event.fileId)
          .toList(),
    ));
  }
  
  Future<void> _onStartUpload(
    StartUploadEvent event,
    Emitter<FileUploadState> emit,
  ) async {
    emit(state.copyWith(isUploading: true));
    
    for (final file in state.selectedFiles) {
      if (file.localFilePath == null) continue;
      
      await _uploadManager.addToQueue(
        fileId: file.id,
        messageId: event.messageId,
        localFilePath: file.localFilePath!,
        fileName: file.fileName,
        fileSize: file.fileSize,
        fileType: file.fileType,
      );
    }
    
    emit(state.copyWith(isUploading: false));
  }
  
  void _onUploadProgress(
    UploadProgressEvent event,
    Emitter<FileUploadState> emit,
  ) {
    final updatedFiles = state.activeUploads.map((f) {
      if (f.id == event.fileId) {
        return f.copyWith(
          uploadProgress: event.progress,
          uploadStatus: event.status,
        );
      }
      return f;
    }).toList();
    
    emit(state.copyWith(activeUploads: updatedFiles));
  }
  
  void _onUploadCompleted(
    UploadCompletedEvent event,
    Emitter<FileUploadState> emit,
  ) {
    final updatedFiles = state.activeUploads
        .where((f) => f.id != event.fileId)
        .toList();
    final completedFiles = [...state.completedFiles, event.file];
    
    emit(state.copyWith(
      activeUploads: updatedFiles,
      completedFiles: completedFiles,
    ));
  }
  
  void _onUploadFailed(
    UploadFailedEvent event,
    Emitter<FileUploadState> emit,
  ) {
    final updatedFiles = state.activeUploads.map((f) {
      if (f.id == event.fileId) {
        return f.copyWith(
          uploadStatus: UploadStatus.failed,
          errorMessage: event.errorMessage,
          retryCount: f.retryCount + 1,
        );
      }
      return f;
    }).toList();
    
    emit(state.copyWith(activeUploads: updatedFiles));
  }
  
  Future<void> _onRetryUpload(
    RetryUploadEvent event,
    Emitter<FileUploadState> emit,
  ) async {
    await _uploadManager.retryUpload(event.fileId);
  }
  
  Future<void> _onCancelUpload(
    CancelUploadEvent event,
    Emitter<FileUploadState> emit,
  ) async {
    await _uploadManager.cancelUpload(event.fileId);
  }
  
  Future<void> _onLoadPendingUploads(
    LoadPendingUploadsEvent event,
    Emitter<FileUploadState> emit,
  ) async {
    final pendingUploads = await _localDataSource.getPendingUploads();
    emit(state.copyWith(
      activeUploads: pendingUploads,
    ));
  }
}
