import 'package:drift/drift.dart';

part 'app_database.g.dart';

// Tables
class PendingUploads extends Table {
  TextColumn get fileId => text()();
  TextColumn get messageId => text()();
  TextColumn get localFilePath => text()();
  TextColumn get fileName => text()();
  IntColumn get fileSize => integer()();
  TextColumn get fileType => text()();
  TextColumn get uploadStatus => text()();
  IntColumn get uploadProgress => integer()();
  IntColumn get retryCount => integer()();
  IntColumn get createdAt => integer()();
  TextColumn get errorMessage => text().nullable()();
  
  @override
  Set<Column> get primaryKey => {fileId};
}

class CachedMessages extends Table {
  TextColumn get id => text()();
  TextColumn get senderId => text()();
  TextColumn get senderName => text().nullable()();
  TextColumn get receiverId => text().nullable()();
  TextColumn get groupId => text().nullable()();
  TextColumn get textContent => text().nullable()();
  TextColumn get messageType => text()();
  TextColumn get status => text()();
  IntColumn get createdAt => integer()();
  
  @override
  Set<Column> get primaryKey => {id};
}

class UploadStates extends Table {
  TextColumn get fileId => text()();
  TextColumn get state => text()(); // JSON string
  IntColumn get updatedAt => integer()();
  
  @override
  Set<Column> get primaryKey => {fileId};
}

@DriftDatabase(tables: [PendingUploads, CachedMessages, UploadStates])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);
  
  @override
  int get schemaVersion => 1;
  
  // Pending uploads queries
  Future<List<PendingUpload>> getAllPendingUploads() =>
      select(pendingUploads).get();
  
  Future<List<PendingUpload>> getPendingUploadsByStatus(String status) =>
      (select(pendingUploads)..where((t) => t.uploadStatus.equals(status))).get();
  
  Future<int> insertPendingUpload(PendingUploadsCompanion entry) =>
      into(pendingUploads).insert(entry);
  
  Future<bool> updatePendingUpload(PendingUploadsCompanion entry) =>
      update(pendingUploads).replace(entry);
  
  Future<int> deletePendingUpload(String fileId) =>
      (delete(pendingUploads)..where((t) => t.fileId.equals(fileId))).go();
  
  // Cached messages queries
  Future<List<CachedMessage>> getMessagesForChat(String chatId) {
    return (select(cachedMessages)
          ..where((t) => t.receiverId.equals(chatId) | t.groupId.equals(chatId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }
  
  Future<int> insertMessage(CachedMessagesCompanion entry) =>
      into(cachedMessages).insert(entry);
  
  Future<int> deleteMessage(String messageId) =>
      (delete(cachedMessages)..where((t) => t.id.equals(messageId))).go();
  
  // Upload state queries
  Future<UploadState?> getUploadState(String fileId) {
    return (select(uploadStates)..where((t) => t.fileId.equals(fileId)))
        .getSingleOrNull();
  }
  
  Future<int> saveUploadState(String fileId, String stateJson) {
    return into(uploadStates).insertOnConflictUpdate(
      UploadStatesCompanion.insert(
        fileId: fileId,
        state: stateJson,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
  
  Future<int> deleteUploadState(String fileId) =>
      (delete(uploadStates)..where((t) => t.fileId.equals(fileId))).go();
}
