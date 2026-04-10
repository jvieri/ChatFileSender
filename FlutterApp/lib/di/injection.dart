import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import '../core/constants.dart';
import '../domain/entities/chat_message.dart';
import '../data/local/app_database.dart';
import '../data/datasources/file_upload_remote_data_source.dart';
import '../data/datasources/file_upload_local_data_source.dart';
import '../data/repositories/file_upload_repository_impl.dart';
import '../data/repositories/chat_message_repository_impl.dart';
import '../domain/repositories/file_upload_repository.dart';
import '../domain/repositories/local_data_source.dart';
import '../domain/repositories/chat_message_repository.dart';
import '../services/signalr_service.dart';
import '../services/upload_manager.dart';
import '../presentation/bloc/chat_bloc.dart';
import '../presentation/bloc/file_upload_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // Database
  final dbPath = p.join(
    (await getApplicationDocumentsDirectory()).path,
    'chat_with_files.db',
  );
  final database = AppDatabase(NativeDatabase.createInBackground(File(dbPath)));
  sl.registerLazySingleton<AppDatabase>(() => database);
  
  // HTTP Client
  final dio = Dio(BaseOptions(
    baseUrl: AppConstants.baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    sendTimeout: const Duration(seconds: 60),
  ));
  
  // Add demo auth interceptor: injects current user ID so the backend
  // can identify who is making the request without a real JWT.
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      final userId = ChatMessage.currentUserId;
      if (userId.isNotEmpty) {
        options.headers['X-User-Id'] = userId;
      }
      return handler.next(options);
    },
    onError: (error, handler) {
      return handler.next(error);
    },
  ));
  
  sl.registerLazySingleton<Dio>(() => dio);
  
  // Data sources
  sl.registerLazySingleton<FileUploadRemoteDataSource>(
    () => FileUploadRemoteDataSource(sl()),
  );
  sl.registerLazySingleton<LocalDataSource>(
    () => LocalDataSourceImpl(sl()),
  );

  // Repositories
  sl.registerLazySingleton<FileUploadRepository>(
    () => FileUploadRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      dio: sl(),
    ),
  );
  sl.registerLazySingleton<ChatMessageRepository>(
    () => ChatMessageRepositoryImpl(sl()),
  );
  
  // Services
  sl.registerLazySingleton<SignalRService>(() => SignalRService());
  
  // Upload Manager
  final uploadManager = UploadManager(
    uploadRepository: sl(),
    localDataSource: sl(),
  );
  await uploadManager.initialize();
  sl.registerLazySingleton<UploadManager>(() => uploadManager);
  
  // BLoCs
  sl.registerFactory(
    () => ChatBloc(
      messageRepository: sl(),
      signalRService: sl(),
    ),
  );
  sl.registerFactory(
    () => FileUploadBloc(
      uploadRepository: sl(),
      localDataSource: sl(),
      uploadManager: sl(),
    ),
  );
}
