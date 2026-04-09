# Architecture: Chat with File Sharing

## System Overview

Real-time chat system with file sharing capabilities supporting:
- **Individual and group messaging** with real-time delivery
- **File uploads** (images, PDFs, Office docs, videos) up to 100MB
- **Real-time upload progress tracking** with percentage updates
- **Background uploads** with retry logic and exponential backoff
- **Post-processing pipeline** (thumbnails, antivirus, validation)
- **Chat simulation** for testing and demonstration
- **Offline persistence** - messages and upload state survive app restarts

## Architecture Pattern

**Clean Architecture + CQRS + Event-Driven**

```
┌─────────────────────────────────────────────────────────────┐
│                      Flutter Client                          │
│  ┌──────────┐  ┌──────────────┐  ┌─────────────────────┐   │
│  │   UI     │  │ BLoC/Cubit   │  │   Repository        │   │
│  │ Screens  │  │   (State)    │  │   (Drift + Dio)     │   │
│  └──────────┘  └──────────────┘  └─────────────────────┘   │
│                           │                                  │
│         ┌─────────────────┼──────────────────┐              │
│         ▼                 ▼                  ▼              │
│    SignalR            Dio HTTP            Drift DB         │
│   (real-time)       (uploads)           (offline)          │
└─────────────────────────────────────────────────────────────┘
         │                     │                   │
         │ HTTP/WS             │ HTTPS             │ Sync
         ▼                     ▼                   ▼
┌─────────────────────────────────────────────────────────────┐
│                      Backend (.NET 8)                        │
│  ┌────────────┐  ┌─────────────┐  ┌────────────────────┐   │
│  │  REST API  │  │  SignalR    │  │  Background Jobs   │   │
│  │ Controllers│  │   Hubs      │  │  (Hosted Services) │   │
│  └────────────┘  └─────────────┘  └────────────────────┘   │
│         │                │                    │              │
│         ▼                ▼                    ▼              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              Application Layer (CQRS)                │    │
│  │         Commands + Queries + Handlers                │    │
│  └─────────────────────────────────────────────────────┘    │
│         │                │                    │              │
│         ▼                ▼                    ▼              │
│  ┌────────────┐  ┌─────────────┐  ┌────────────────────┐   │
│  │   Domain   │  │ Infrastructure│  │   Entity Framework │   │
│  │  Entities  │  │   Services   │  │   SQL Server       │   │
│  └────────────┘  └─────────────┘  └────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
         │                     │                   │
         │                     │                   │
         ▼                     ▼                   ▼
   ┌──────────┐          ┌──────────┐        ┌──────────┐
   │ RabbitMQ │          │ S3/Blob  │        │ SQL Srv  │
   │ (events) │          │ (files)  │        │  (data)  │
   └──────────┘          └──────────┘        └──────────┘
```

## Database Schema

### Tables

```sql
-- Users
CREATE TABLE Users (
    Id UNIQUEIDENTIFIER PRIMARY KEY,
    Username NVARCHAR(100) NOT NULL,
    Email NVARCHAR(255) NOT NULL,
    CreatedAt DATETIME2 DEFAULT SYSUTCDATETIME()
);

-- Chat Groups
CREATE TABLE ChatGroups (
    Id UNIQUEIDENTIFIER PRIMARY KEY,
    Name NVARCHAR(200) NOT NULL,
    CreatedBy UNIQUEIDENTIFIER REFERENCES Users(Id),
    CreatedAt DATETIME2 DEFAULT SYSUTCDATETIME()
);

-- Group Members
CREATE TABLE ChatGroupMembers (
    Id UNIQUEIDENTIFIER PRIMARY KEY,
    GroupId UNIQUEIDENTIFIER REFERENCES ChatGroups(Id),
    UserId UNIQUEIDENTIFIER REFERENCES Users(Id),
    JoinedAt DATETIME2 DEFAULT SYSUTCDATETIME(),
    UNIQUE(GroupId, UserId)
);

-- Chat Messages
CREATE TABLE ChatMessages (
    Id UNIQUEIDENTIFIER PRIMARY KEY,
    SenderId UNIQUEIDENTIFIER REFERENCES Users(Id),
    GroupId UNIQUEIDENTIFIER NULL REFERENCES ChatGroups(Id),
    ReceiverId UNIQUEIDENTIFIER NULL REFERENCES Users(Id),
    TextContent NVARCHAR(MAX) NULL,
    MessageType VARCHAR(20) DEFAULT 'Text', -- Text, File, System
    CreatedAt DATETIME2 DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2 NULL,
    
    -- Index for fast queries
    INDEX IX_Messages_User (ReceiverId, CreatedAt),
    INDEX IX_Messages_Group (GroupId, CreatedAt)
);

-- File Attachments
CREATE TABLE FileAttachments (
    Id UNIQUEIDENTIFIER PRIMARY KEY,
    MessageId UNIQUEIDENTIFIER REFERENCES ChatMessages(Id),
    FileName NVARCHAR(255) NOT NULL,
    OriginalFileName NVARCHAR(255) NOT NULL,
    FileType VARCHAR(50) NOT NULL, -- mime type
    FileExtension VARCHAR(10) NOT NULL,
    FileSize BIGINT NOT NULL, -- bytes
    StorageKey NVARCHAR(500) NOT NULL, -- S3/Blob key
    StorageProvider VARCHAR(20) DEFAULT 'AzureBlob', -- AzureBlob, S3
    
    -- Upload tracking
    UploadStatus VARCHAR(20) DEFAULT 'Pending', -- Pending, Uploading, Uploaded, Processing, Completed, Failed
    UploadProgress INT DEFAULT 0, -- 0-100
    UploadStartedAt DATETIME2 NULL,
    UploadCompletedAt DATETIME2 NULL,
    
    -- Post-processing
    ProcessingStatus VARCHAR(20) DEFAULT 'Pending', -- Pending, InProgress, Completed, Failed
    ThumbnailUrl NVARCHAR(500) NULL,
    IsScanned BIT DEFAULT 0,
    ScanStatus VARCHAR(20) NULL, -- Clean, Infected, Skipped
    ScanResult NVARCHAR(MAX) NULL,
    
    -- Metadata
    Width INT NULL, -- for images/videos
    Height INT NULL,
    Duration INT NULL, -- seconds for videos/audio
    ErrorMessage NVARCHAR(MAX) NULL,
    RetryCount INT DEFAULT 0,
    CreatedAt DATETIME2 DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2 NULL,
    
    INDEX IX_Files_Message (MessageId),
    INDEX IX_Files_UploadStatus (UploadStatus),
    INDEX IX_Files_ProcessingStatus (ProcessingStatus)
);

-- Upload Sessions (for resume capability)
CREATE TABLE UploadSessions (
    Id UNIQUEIDENTIFIER PRIMARY KEY,
    FileAttachmentId UNIQUEIDENTIFIER REFERENCES FileAttachments(Id),
    UserId UNIQUEIDENTIFIER REFERENCES Users(Id),
    PresignedUrl NVARCHAR(1000) NOT NULL,
    PresignedUrlExpiresAt DATETIME2 NOT NULL,
    SessionStatus VARCHAR(20) DEFAULT 'Active', -- Active, Completed, Expired, Cancelled
    CreatedAt DATETIME2 DEFAULT SYSUTCDATETIME(),
    
    INDEX IX_Sessions_User (UserId),
    INDEX IX_Sessions_Status (SessionStatus, PresignedUrlExpiresAt)
);
```

## API Endpoints

### Chat Messages

#### Send Text Message
```
POST /api/v1/messages
Authorization: Bearer {token}
Content-Type: application/json

Request Body:
{
  "receiverId": "uuid",  // optional for group messages
  "groupId": "uuid",     // optional for direct messages
  "textContent": "Hello, how are you?"
}

Response: 201 Created
{
  "id": "uuid",
  "senderId": "uuid",
  "receiverId": "uuid",
  "groupId": null,
  "textContent": "Hello, how are you?",
  "messageType": "Text",
  "status": "Sent",
  "attachments": [],
  "createdAt": "2024-01-01T12:00:00Z"
}
```

#### Get Messages
```
GET /api/v1/messages?userId=uuid&groupId=uuid&page=1&pageSize=50
Authorization: Bearer {token}

Response: 200 OK
{
  "messages": [...],
  "totalCount": 100,
  "page": 1,
  "pageSize": 50
}
```

### File Upload Endpoints

#### Create Message with File
```
POST /api/v1/messages/with-file
Authorization: Bearer {token}
Content-Type: application/json

Request Body:
{
  "receiverId": "uuid",
  "groupId": "uuid",
  "textContent": "Check this file",
  "files": [
    {
      "fileName": "photo.jpg",
      "fileSize": 1048576,
      "fileType": "image/jpeg"
    }
  ]
}

Response: 201 Created
{
  "messageId": "uuid",
  "uploadUrls": [
    {
      "fileId": "uuid",
      "uploadUrl": "https://storage...presigned-url",
      "expiresAt": "2024-01-01T13:00:00Z"
    }
  ]
}
```

## Simulation Endpoints

For testing and demonstration purposes:

### Initialize Demo Data
```
POST /api/v1/simulation/initialize

Response: 200 OK
{
  "message": "Demo data created successfully",
  "users": [
    { "id": "uuid1", "username": "user1", "displayName": "Alice" },
    { "id": "uuid2", "username": "user2", "displayName": "Bob" },
    { "id": "uuid3", "username": "user3", "displayName": "Charlie" }
  ],
  "groups": [
    { "id": "uuid", "name": "Development Team", "description": "Team chat" }
  ]
}
```

### Get Demo Users
```
GET /api/v1/simulation/users

Response: 200 OK
{
  "users": [...]
}
```

### Get Demo Groups
```
GET /api/v1/simulation/groups

Response: 200 OK
{
  "groups": [...]
}
```

### 3. Get File Download URL
```
GET /api/v1/files/{fileId}/download-url
Authorization: Bearer {token}

Response: 200 OK
{
  "downloadUrl": "https://storage...presigned-download-url",
  "expiresAt": "2024-01-01T12:00:00Z",
  "fileName": "photo.jpg",
  "fileSize": 1048576
}
```

### 4. Retry Failed Upload
```
POST /api/v1/files/{fileId}/retry
Authorization: Bearer {token}

Response: 200 OK
{
  "uploadUrl": "https://storage...new-presigned-url",
  "expiresAt": "2024-01-01T12:00:00Z"
}
```

### 5. Confirm File Upload
```
POST /api/v1/files/{fileId}/confirm
Authorization: Bearer {token}

Request Body:
{
  "checksum": "optional-md5"
}

Response: 200 OK
{
  "fileId": "uuid",
  "status": "Processing"
}
```

## Chat Features

### Message Types
- **Text**: Plain text messages with emoji support
- **File**: Messages with file attachments
- **Image**: Image messages with thumbnails
- **Video**: Video messages with preview
- **System**: System notifications (user joined, left, etc.)

### Message Status
- **Sent**: Message saved to database
- **Delivered**: Message delivered to recipient
- **Read**: Recipient has read the message
- **Deleted**: Message was deleted

### Real-time Features via SignalR

#### Server → Client Events
```dart
// New message received
Clients.Group(chatId).SendAsync("ReceiveMessage", {...});

// File upload progress update
Clients.User(userId).SendAsync("FileUploadProgress", {
  fileId: "uuid",
  progress: 45,
  status: "Uploading"
});

// File processing completed
Clients.Group(chatId).SendAsync("FileProcessingCompleted", {
  fileId: "uuid",
  thumbnailUrl: "https://...",
  metadata: {...}
});

// File error occurred
Clients.Group(chatId).SendAsync("FileError", {
  fileId: "uuid",
  errorMessage: "File too large"
});

// Typing indicator
Clients.Group(chatId).SendAsync("TypingIndicator", {
  userId: "uuid",
  userName: "Alice",
  isTyping: true
});
```

#### Client → Server Events
```dart
// Join chat room
await hubConnection.invoke("JoinChat", args: [chatId]);

// Leave chat room
await hubConnection.invoke("LeaveChat", args: [chatId]);

// Report upload progress
await hubConnection.invoke("ReportUploadProgress", 
  args: [fileId, progress, status]);

// Send typing indicator
await hubConnection.invoke("SendTypingIndicator", 
  args: [chatId, isTyping]);
```

### Chat Simulation Features

The system includes a built-in simulation mode for testing and demonstration:

#### Flutter App Simulator Panel
- **Toggle**: Tap the science icon in the app bar to show/hide
- **Demo Users**: Alice, Bob, Charlie, Diana with predefined messages
- **Quick Test**: Send a test message with one tap
- **Real-time Updates**: Simulated messages appear instantly

#### Backend Simulation Endpoint
- Initialize demo data: `POST /api/v1/simulation/initialize`
- Creates 3 demo users and 1 demo group
- Ready to use for testing chat functionality

### Flutter BLoC Architecture

#### ChatBloc
Manages chat state and handles:
- Loading messages (pagination support)
- Sending text messages
- Receiving real-time messages via SignalR
- File upload progress tracking
- Chat join/leave events
- Message simulation for testing

**States:**
```dart
ChatState {
  isLoading: bool,
  isConnected: bool,
  hasMore: bool,
  currentPage: int,
  chatId: String?,
  userId: String?,
  groupId: String?,
  errorMessage: String?,
  messages: List<ChatMessage>
}
```

**Events:**
```dart
- LoadMessagesEvent
- LoadMoreMessagesEvent (pagination)
- SendMessageEvent
- SendFileMessageEvent
- ReceiveMessageEvent (from SignalR)
- UpdateFileProgressEvent
- UpdateFileCompletedEvent
- UpdateFileErrorEvent
- JoinChatEvent
- LeaveChatEvent
- SimulateReceiveMessageEvent (for testing)
```

#### FileUploadBloc
Manages file upload state and handles:
- File selection and validation
- Upload queue management
- Progress tracking
- Retry logic
- Cancel uploads

**States:**
```dart
FileUploadState {
  isLoading: bool,
  isUploading: bool,
  errorMessage: String?,
  selectedFiles: List<FileAttachment>,
  activeUploads: List<FileAttachment>,
  completedFiles: List<FileAttachment>,
  failedUploads: List<FileAttachment>
}
```

### UI Components

#### ChatScreen
Main chat interface with:
- Message list with infinite scroll
- Message input with send button
- File attachment button
- File upload progress bar
- Simulator panel (toggleable)
- Selected files preview (bottom sheet)

#### MessageBubbleWidget
Displays individual messages with:
- Sender name and color coding
- Text content
- File attachments with progress
- Timestamp and delivery status
- Mine vs others alignment

#### FileAttachmentWidget
Displays file attachments with:
- File type icon/image preview
- File name and size
- Upload progress indicator
- Status badges (pending, uploading, processing, completed, failed)
- Retry button for failed uploads
- Cancel button for pending uploads

### Offline Support

#### Drift Database Tables
- **PendingUploads**: Tracks files waiting to upload
- **CachedMessages**: Local message cache
- **UploadStates**: Upload session state persistence

#### Behavior
- Pending uploads persist across app restarts
- Cached messages available offline
- Upload state survives network disconnections
- Automatic resume when connection restored

### 5. Confirm File Upload
```
POST /api/v1/files/{fileId}/confirm
Authorization: Bearer {token}

Request Body:
{
  "checksum": "optional-md5"
}

Response: 200 OK
{
  "fileId": "uuid",
  "status": "Processing"
}
```
```
GET /api/v1/files/{fileId}/download-url
Authorization: Bearer {token}

Response: 200 OK
{
  "downloadUrl": "https://storage...presigned-download-url",
  "expiresAt": "2024-01-01T12:00:00Z",
  "fileName": "photo.jpg",
  "fileSize": 1048576
}
```

### 4. Retry Failed Upload
```
POST /api/v1/files/{fileId}/retry
Authorization: Bearer {token}

Response: 200 OK
{
  "uploadUrl": "https://storage...new-presigned-url",
  "expiresAt": "2024-01-01T12:00:00Z"
}
```

## SignalR Events

### Client → Server
```csharp
// Join chat room
await hubConnection.InvokeAsync("JoinChat", chatId);

// Leave chat room
await hubConnection.InvokeAsync("LeaveChat", chatId);

// File upload progress (from client for tracking)
await hubConnection.InvokeAsync("ReportUploadProgress", new {
    fileId = "uuid",
    progress = 45,
    status = "Uploading"
});
```

### Server → Client
```csharp
// New message with file
Clients.Group(chatId).SendAsync("ReceiveMessage", new {
    messageId = "uuid",
    senderId = "uuid",
    textContent = "Check this file",
    files = [{
        fileId = "uuid",
        fileName = "photo.jpg",
        fileType = "image/jpeg",
        fileSize = 1048576,
        uploadStatus = "Uploaded",
        thumbnailUrl = null
    }]
});

// File upload progress update
Clients.User(receiverId).SendAsync("FileUploadProgress", new {
    fileId = "uuid",
    progress = 75,
    status = "Uploading"
});

// File processing complete
Clients.Group(chatId).SendAsync("FileProcessingCompleted", new {
    fileId = "uuid",
    thumbnailUrl = "https://...",
    metadata = { width: 1920, height: 1080 }
});

// File error
Clients.Group(chatId).SendAsync("FileError", new {
    fileId = "uuid",
    errorMessage = "File too large"
});
```

## Android Upload Strategy

### WorkManager Queue Design
```
UniqueWorkName: "upload_{messageId}_{fileId}"
Constraints: Network connected
BackoffPolicy: Exponential (10s, 20s, 40s, max 1h)
ExistingWorkPolicy: REPLACE (allows retry)
```

### Concurrent Uploads
```kotlin
private val uploadDispatcher = Executor(
    Executors.newFixedThreadPool(3) // max 3 concurrent uploads
)
```

### Progress Tracking
```kotlin
// Using OkHttp Progress Listener
class ProgressRequestBody(
    private val delegate: RequestBody,
    private val listener: (bytesWritten: Long, contentLength: Long) -> Unit
) : RequestBody() {
    // ...
}

// Update WorkManager progress
workRequest.setProgressAsync(
    Data.Builder().apply {
        putInt(PROGRESS_KEY, percentage)
        putString(STATUS_KEY, "Uploading")
    }.build()
)
```

### Offline Persistence
```kotlin
// Room Database
@Entity(tableName = "pending_uploads")
data class PendingUpload(
    @PrimaryKey val fileId: String,
    val messageId: String,
    val localUri: String,
    val fileName: String,
    val fileSize: Long,
    val status: UploadStatus,
    val progress: Int,
    val retryCount: Int,
    val createdAt: Long
)

// Restore on app restart
@Query("SELECT * FROM pending_uploads WHERE status != 'Completed' ORDER BY createdAt")
fun getPendingUploads(): Flow<List<PendingUpload>>
```

## Security Considerations

### File Validation
```csharp
// Allowed file types
private static readonly AllowedTypes = new HashSet<string> {
    // Images
    "image/jpeg", "image/png", "image/gif", "image/webp",
    // Documents
    "application/pdf",
    "application/msword",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/vnd.ms-excel",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    // Videos
    "video/mp4", "video/webm", "video/quicktime",
    // Archives
    "application/zip", "application/x-rar-compressed"
};

// Max file size: 100MB
private const long MaxFileSize = 100 * 1024 * 1024;
```

### Presigned URL Expiration
```csharp
// Upload URLs expire in 1 hour
var presignedUrl = await storage.GenerateUploadUrlAsync(
    key: storageKey,
    expiration: TimeSpan.FromHours(1),
    maxSize: MaxFileSize
);

// Download URLs expire in 24 hours
var downloadUrl = await storage.GenerateDownloadUrlAsync(
    key: storageKey,
    expiration: TimeSpan.FromHours(24)
);
```

### Access Control
```csharp
// Only message participants can access files
public async Task<bool> CanAccessFile(Guid userId, Guid fileId)
{
    var attachment = await _context.FileAttachments.FindAsync(fileId);
    var message = await _context.ChatMessages.FindAsync(attachment.MessageId);
    
    return message.SenderId == userId ||
           message.ReceiverId == userId ||
           (message.GroupId.HasValue && 
            await _context.ChatGroupMembers.AnyAsync(
                m => m.GroupId == message.GroupId && m.UserId == userId));
}
```

## RabbitMQ Message Types

### FileUploadedEvent
```csharp
public record FileUploadedEvent(
    Guid FileId,
    Guid MessageId,
    string FileType,
    string StorageKey,
    long FileSize
);
```

### FileProcessingCompletedEvent
```csharp
public record FileProcessingCompletedEvent(
    Guid FileId,
    string ThumbnailUrl,
    int? Width,
    int? Height,
    int? Duration
);
```

### FileProcessingFailedEvent
```csharp
public record FileProcessingFailedEvent(
    Guid FileId,
    string ErrorMessage,
    int RetryCount
);
```

## RabbitMQ Queues

```
Queue: file-processing
  - FileUploadedEvent
  - DLQ: file-processing-dlq
  - Prefetch: 10
  - Consumers: 3 (thumbnail, antivirus, metadata)

Queue: file-processing-results
  - FileProcessingCompletedEvent
  - FileProcessingFailedEvent
  - Consumers: 1 (SignalR notifier)
```

## Error Handling & Retry Strategy

### Android Side
```kotlin
sealed class UploadError {
    object NetworkError : UploadError()
    object ServerError : UploadError()
    object FileTooLarge : UploadError()
    object InvalidFileType : UploadError()
    object StorageFull : UploadError()
    data class Unknown(val message: String) : UploadError()
}

// Retry with exponential backoff
fun calculateRetryDelay(attempt: Int): Duration {
    val baseDelay = Duration.ofSeconds(10)
    return minOf(
        baseDelay.multipliedBy(2L.pow(attempt).toLong()),
        Duration.ofHours(1)
    )
}

// Handle app backgrounding
workManager.enqueueUniqueWork(
    "upload_$fileId",
    ExistingWorkPolicy.REPLACE,
    uploadWorkRequest
)
```

### Backend Side
```csharp
// RabbitMQ retry with dead letter queue
var retryPolicy = Policy
    .Handle<Exception>()
    .WaitAndRetryAsync(
        retryCount: 3,
        sleepDurationProvider: attempt => TimeSpan.FromSeconds(Math.Pow(2, attempt)),
        onRetry: (exception, timespan, retryCount, context) => {
            _logger.LogWarning(exception, "Retry {RetryCount} for file {FileId}", 
                retryCount, context["FileId"]);
        }
    );
```

## Scalability Considerations

1. **Never send files through RabbitMQ** - Only events/metadata
2. **Direct-to-storage uploads** - Files go straight to S3/Azure Blob
3. **Async processing** - Thumbnails/antivirus run in background
4. **Connection pooling** - SignalR uses Redis backplane for scale-out
5. **CDN** - Serve downloads via CDN for better performance
6. **Rate limiting** - Prevent abuse with per-user upload limits
