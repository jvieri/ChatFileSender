import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/constants.dart';
import '../domain/entities/file_attachment.dart';
import '../domain/repositories/file_upload_repository.dart';
import '../domain/repositories/local_data_source.dart';

enum UploadQueueStatus { pending, uploading, uploaded, processing, completed, failed, cancelled }

class UploadTask {
  final String fileId;
  final String messageId;
  final String localFilePath;
  final String fileName;
  final int fileSize;
  final String fileType;
  final UploadQueueStatus status;
  final int progress;
  final int retryCount;
  final DateTime createdAt;
  final DateTime? nextRetryAt;
  final String? errorMessage;
  
  const UploadTask({
    required this.fileId,
    required this.messageId,
    required this.localFilePath,
    required this.fileName,
    required this.fileSize,
    required this.fileType,
    this.status = UploadQueueStatus.pending,
    this.progress = 0,
    this.retryCount = 0,
    required this.createdAt,
    this.nextRetryAt,
    this.errorMessage,
  });
  
  bool get canRetry =>
      retryCount < AppConstants.maxRetries &&
      status == UploadQueueStatus.failed;

  UploadTask copyWith({
    UploadQueueStatus? status,
    int? progress,
    int? retryCount,
    DateTime? nextRetryAt,
    String? errorMessage,
  }) {
    return UploadTask(
      fileId: fileId,
      messageId: messageId,
      localFilePath: localFilePath,
      fileName: fileName,
      fileSize: fileSize,
      fileType: fileType,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class UploadManager {
  final FileUploadRepository _uploadRepository;
  final LocalDataSource _localDataSource;
  final Map<String, UploadTask> _uploadQueue = {};
  final _progressController = StreamController<UploadTask>.broadcast();
  final _completedController = StreamController<UploadTask>.broadcast();
  final _errorController = StreamController<UploadTask>.broadcast();
  
  Stream<UploadTask> get progressStream => _progressController.stream;
  Stream<UploadTask> get completedStream => _completedController.stream;
  Stream<UploadTask> get errorStream => _errorController.stream;
  
  List<UploadTask> get queuedUploads => 
      _uploadQueue.values.where((t) => t.status == UploadQueueStatus.pending).toList();
  List<UploadTask> get activeUploads => 
      _uploadQueue.values.where((t) => t.status == UploadQueueStatus.uploading).toList();
  List<UploadTask> get failedUploads => 
      _uploadQueue.values.where((t) => t.status == UploadQueueStatus.failed).toList();
  
  int _activeUploadCount = 0;
  
  UploadManager({
    required FileUploadRepository uploadRepository,
    required LocalDataSource localDataSource,
  })  : _uploadRepository = uploadRepository,
        _localDataSource = localDataSource;
  
  Future<void> initialize() async {
    // Load pending uploads from local storage
    final pendingUploads = await _localDataSource.getPendingUploads();
    for (final upload in pendingUploads) {
      final task = UploadTask(
        fileId: upload.id,
        messageId: upload.messageId,
        localFilePath: upload.localFilePath ?? '',
        fileName: upload.fileName,
        fileSize: upload.fileSize,
        fileType: upload.fileType,
        status: _convertStatus(upload.uploadStatus),
        progress: upload.uploadProgress,
        retryCount: upload.retryCount,
        createdAt: upload.createdAt,
        errorMessage: upload.errorMessage,
      );
      _uploadQueue[upload.id] = task;
    }
    
    // Start processing queue
    _processQueue();
  }
  
  Future<void> addToQueue({
    required String fileId,
    required String messageId,
    required String localFilePath,
    required String fileName,
    required int fileSize,
    required String fileType,
  }) async {
    final task = UploadTask(
      fileId: fileId,
      messageId: messageId,
      localFilePath: localFilePath,
      fileName: fileName,
      fileSize: fileSize,
      fileType: fileType,
      createdAt: DateTime.now(),
    );
    
    _uploadQueue[fileId] = task;
    
    // Save to local storage for persistence
    await _localDataSource.saveUploadState(fileId, {
      'fileId': fileId,
      'messageId': messageId,
      'localFilePath': localFilePath,
      'fileName': fileName,
      'fileSize': fileSize,
      'fileType': fileType,
      'status': task.status.name,
      'progress': task.progress,
      'retryCount': task.retryCount,
      'createdAt': task.createdAt.toIso8601String(),
    });
    
    // Trigger queue processing
    _processQueue();
  }
  
  Future<void> _processQueue() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return; // No internet, wait for connection
    }
    
    while (_activeUploadCount < AppConstants.maxConcurrentUploads) {
      final pendingTask = _uploadQueue.values
          .where((t) => t.status == UploadQueueStatus.pending)
          .firstOrNull;
      
      if (pendingTask == null) break;
      
      _activeUploadCount++;
      _startUpload(pendingTask);
    }
  }
  
  Future<void> _startUpload(UploadTask task) async {
    final updatedTask = task.copyWith(status: UploadQueueStatus.uploading);
    _uploadQueue[task.fileId] = updatedTask;
    _progressController.add(updatedTask);
    
    try {
      // Get upload session (would be created when message is created)
      // For now, simulate upload with progress
      final file = File(task.localFilePath);
      if (!await file.exists()) {
        throw Exception('File not found: ${task.localFilePath}');
      }
      
      // Simulate upload progress (in real app, this uses Dio with presigned URL)
      for (int progress = 0; progress <= 100; progress += 10) {
        await Future.delayed(const Duration(milliseconds: 100));
        final progressTask = _uploadQueue[task.fileId]!.copyWith(progress: progress);
        _uploadQueue[task.fileId] = progressTask;
        _progressController.add(progressTask);
        
        // Save progress to local storage
        await _localDataSource.saveUploadState(task.fileId, {
          'fileId': task.fileId,
          'status': progressTask.status.name,
          'progress': progressTask.progress,
        });
      }
      
      // Mark as uploaded
      final completedTask = _uploadQueue[task.fileId]!.copyWith(
        status: UploadQueueStatus.uploaded,
        progress: 100,
      );
      _uploadQueue[task.fileId] = completedTask;
      _completedController.add(completedTask);
      
      // Confirm upload with backend
      await _uploadRepository.confirmUpload(task.fileId);
      
      _activeUploadCount--;
      _processQueue();
      
    } catch (e) {
      final failedTask = _uploadQueue[task.fileId]!.copyWith(
        status: UploadQueueStatus.failed,
        errorMessage: e.toString(),
        retryCount: task.retryCount + 1,
        nextRetryAt: _calculateNextRetry(task.retryCount),
      );
      _uploadQueue[task.fileId] = failedTask;
      _errorController.add(failedTask);
      
      _activeUploadCount--;
      _processQueue();
    }
  }
  
  Future<void> retryUpload(String fileId) async {
    final task = _uploadQueue[fileId];
    if (task == null || !task.canRetry) return;
    
    final retryTask = task.copyWith(
      status: UploadQueueStatus.pending,
      progress: 0,
      errorMessage: null,
    );
    _uploadQueue[fileId] = retryTask;
    _processQueue();
  }
  
  Future<void> cancelUpload(String fileId) async {
    final task = _uploadQueue[fileId];
    if (task == null) return;
    
    final cancelledTask = task.copyWith(status: UploadQueueStatus.cancelled);
    _uploadQueue[fileId] = cancelledTask;
  }
  
  DateTime _calculateNextRetry(int retryCount) {
    final delay = AppConstants.baseRetryDelay * (1 << retryCount);
    final actualDelay =
        delay > AppConstants.maxRetryDelay ? AppConstants.maxRetryDelay : delay;
    return DateTime.now().add(actualDelay);
  }

  UploadQueueStatus _convertStatus(UploadStatus status) {
    switch (status) {
      case UploadStatus.pending:
        return UploadQueueStatus.pending;
      case UploadStatus.uploading:
        return UploadQueueStatus.uploading;
      case UploadStatus.uploaded:
        return UploadQueueStatus.uploaded;
      case UploadStatus.processing:
        return UploadQueueStatus.processing;
      case UploadStatus.completed:
        return UploadQueueStatus.completed;
      case UploadStatus.failed:
        return UploadQueueStatus.failed;
      case UploadStatus.cancelled:
        return UploadQueueStatus.cancelled;
    }
  }
  
  void dispose() {
    _progressController.close();
    _completedController.close();
    _errorController.close();
  }
}
