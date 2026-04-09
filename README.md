# Chat with File Sharing

A real-time chat system with file sharing capabilities built with **.NET 8 Backend** + **Flutter Mobile App**, featuring SignalR for real-time updates, RabbitMQ for async processing, and Azure Blob Storage for file management.

---

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Features](#features)
- [Technology Stack](#technology-stack)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Backend Setup](#backend-setup)
- [Flutter App Setup](#flutter-app-setup)
- [Database Setup](#database-setup)
- [Configuration](#configuration)
- [Running the System](#running-the-system)
- [API Endpoints](#api-endpoints)
- [SignalR Events](#signalr-events)
- [RabbitMQ Message Flow](#rabbitmq-message-flow)
- [File Upload Flow](#file-upload-flow)
- [Security](#security)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                        Flutter App                            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐ │
│  │   UI     │  │   BLoC   │  │  Domain  │  │    Data      │ │
│  │ Screens  │→ │ (State)  │→ │ UseCases │→ │  Repository  │ │
│  └──────────┘  └──────────┘  └──────────┘  └──────────────┘ │
│                            ↓                                   │
│         ┌──────────────────┼──────────────────┐               │
│         ↓                  ↓                  ↓               │
│    SignalR            Dio HTTP           Drift DB            │
│   (real-time)      (uploads)           (offline)              │
└──────────────────────────────────────────────────────────────┘
         ↓                     ↓                  ↓
         │ WebSocket           │ HTTPS            │ Local
         ↓                     ↓                  ↓
┌──────────────────────────────────────────────────────────────┐
│                     Backend (.NET 8)                          │
│  ┌────────────┐  ┌─────────────┐  ┌────────────────────┐    │
│  │  REST API  │  │  SignalR    │  │  Background Jobs   │    │
│  │Controllers │  │   Hubs      │  │  (RabbitMQ)        │    │
│  └────────────┘  └─────────────┘  └────────────────────┘    │
│         ↓                ↓                    ↓              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │         Application Layer (CQRS + MediatR)           │    │
│  └─────────────────────────────────────────────────────┘    │
│         ↓                ↓                    ↓              │
│  ┌────────────┐  ┌─────────────┐  ┌────────────────────┐    │
│  │   Domain   │  │   Entity    │  │   Azure Blob       │    │
│  │  Entities  │  │  Framework  │  │   Storage          │    │
│  └────────────┘  └─────────────┘  └────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
         ↓                     ↓                   ↓
   ┌──────────┐          ┌──────────┐        ┌──────────┐
   │ RabbitMQ │          │  Azure   │        │   SQL    │
   │  (MQ)    │          │  Blob    │        │  Server  │
   └──────────┘          └──────────┘        └──────────┘
```

---

## Features

### Core Features
- ✅ Real-time messaging (individual & group chats)
- ✅ File uploads up to **100 MB** per file
- ✅ Support for images, PDFs, Office docs, videos, and more
- ✅ Real-time upload progress tracking (0-100%)
- ✅ Multiple concurrent uploads (max 3 at once)
- ✅ Upload queue management
- ✅ Automatic retry with exponential backoff
- ✅ Offline persistence (survives app restart)
- ✅ Background uploads via WorkManager

### File States
- **Pending**: Waiting to start upload
- **Uploading**: Actively uploading (shows progress %)
- **Uploaded**: Upload complete, waiting for processing
- **Processing**: Backend generating thumbnails/metadata
- **Completed**: File ready, thumbnail available
- **Failed**: Error occurred, can retry
- **Cancelled**: User cancelled the upload

### Security Features
- ✅ File type validation (whitelist-based)
- ✅ File size limits (100 MB max)
- ✅ Presigned URLs with expiration (1 hour for upload, 24 hours for download)
- ✅ Access control (only chat participants can access files)
- ✅ Antivirus scanning pipeline (pluggable)
- ✅ Rate limiting support

---

## Technology Stack

### Backend
| Component | Technology |
|-----------|-----------|
| Framework | .NET 8 / ASP.NET Core |
| ORM | Entity Framework Core |
| Database | SQL Server 2019+ |
| Real-time | SignalR + MessagePack |
| Message Queue | RabbitMQ |
| Storage | Azure Blob Storage |
| Auth | JWT Bearer Tokens |
| API Docs | Swagger/OpenAPI |
| Architecture | Clean Architecture + CQRS |

### Flutter App
| Component | Technology |
|-----------|-----------|
| Framework | Flutter 3.16+ |
| State Management | flutter_bloc (BLoC) |
| HTTP Client | Dio |
| SignalR | signalr_netcore |
| Local DB | Drift (SQLite) |
| File Picker | file_picker |
| Background Work | workmanager |
| DI | get_it |
| UI | Material 3 |

---

## Project Structure

```
demoRabbitMQ/
├── ChatWithFiles.sln                 # .NET Solution
├── ChatWithFiles.Api/                # Web API project
│   ├── Controllers/                  # REST endpoints
│   │   ├── MessagesController.cs
│   │   └── FilesController.cs
│   ├── Middleware/
│   │   └── CurrentUserAccessor.cs
│   ├── Program.cs                    # App entry point
│   └── appsettings.json              # Configuration
│
├── ChatWithFiles.Application/        # Application layer (CQRS)
│   ├── Commands/
│   │   ├── Messages/
│   │   │   └── CreateMessageWithFileCommand.cs
│   │   └── Files/
│   │       └── ConfirmFileUploadCommand.cs
│   └── Queries/
│       └── Files/
│           └── GetFileDownloadUrlQuery.cs
│
├── ChatWithFiles.Domain/             # Domain layer
│   ├── Entities/                     # Domain entities
│   │   ├── User.cs
│   │   ├── ChatGroup.cs
│   │   ├── ChatMessage.cs
│   │   ├── FileAttachment.cs
│   │   └── UploadSession.cs
│   ├── Enums/
│   │   └── FileEnums.cs
│   └── Interfaces/                   # Repository & service interfaces
│       ├── IRepositories.cs
│       └── IServices.cs
│
├── ChatWithFiles.Infrastructure/     # Infrastructure layer
│   ├── Persistence/
│   │   └── ChatDbContext.cs          # EF Core DbContext
│   ├── Repositories/
│   │   ├── EfRepository.cs
│   │   ├── EfChatMessageRepository.cs
│   │   ├── EfFileAttachmentRepository.cs
│   │   └── EfUnitOfWork.cs
│   ├── Services/
│   │   ├── AzureBlobStorageService.cs
│   │   ├── RabbitMqMessageBus.cs
│   │   └── SignalRChatHubService.cs
│   ├── Hubs/
│   │   └── ChatHub.cs                # SignalR hub
│   └── Consumers/
│       └── FileProcessingConsumer.cs # RabbitMQ consumer
│
├── ChatWithFiles.Contracts/          # DTOs & contracts
│   ├── Files/
│   │   └── FileDtos.cs
│   ├── Messages/
│   │   └── MessageDtos.cs
│   └── SignalR/
│       └── SignalREvents.cs
│
├── Database/
│   └── Schema.sql                    # Database schema & stored procedures
│
├── FlutterApp/                       # Flutter mobile app
│   ├── lib/
│   │   ├── core/                     # Constants, failures, utils
│   │   │   ├── constants.dart
│   │   │   ├── failure.dart
│   │   │   └── use_result.dart
│   │   ├── data/                     # Data layer
│   │   │   ├── datasources/
│   │   │   │   ├── file_upload_remote_data_source.dart
│   │   │   │   └── file_upload_local_data_source.dart
│   │   │   ├── models/
│   │   │   │   └── file_attachment_model.dart
│   │   │   ├── repositories/
│   │   │   │   └── file_upload_repository_impl.dart
│   │   │   └── local/
│   │   │       └── app_database.dart  # Drift database
│   │   ├── domain/                   # Domain layer
│   │   │   ├── entities/
│   │   │   │   ├── file_attachment.dart
│   │   │   │   └── chat_message.dart
│   │   │   ├── repositories/
│   │   │   │   ├── file_upload_repository.dart
│   │   │   │   ├── chat_message_repository.dart
│   │   │   │   └── local_data_source.dart
│   │   │   └── usecases/
│   │   │       ├── create_message_with_file.dart
│   │   │       ├── upload_file.dart
│   │   │       ├── confirm_upload.dart
│   │   │       └── get_download_url.dart
│   │   ├── presentation/             # UI layer
│   │   │   ├── bloc/
│   │   │   │   ├── chat_bloc.dart
│   │   │   │   └── file_upload_bloc.dart
│   │   │   ├── screens/
│   │   │   │   └── chat_screen.dart
│   │   │   └── widgets/
│   │   │       └── file_attachment_widget.dart
│   │   ├── services/                 # Services
│   │   │   ├── signalr_service.dart
│   │   │   └── upload_manager.dart
│   │   ├── di/
│   │   │   └── injection.dart         # Dependency injection
│   │   └── main.dart
│   ├── android/app/src/main/
│   │   └── AndroidManifest.xml        # Android permissions
│   └── pubspec.yaml                   # Flutter dependencies
│
└── ARCHITECTURE.md                    # Architecture documentation
```

---

## Prerequisites

### Backend
- .NET 8 SDK: https://dotnet.microsoft.com/download
- SQL Server 2019+ (or SQL Server Express)
- RabbitMQ: https://www.rabbitmq.com/download.html
- Azure Storage Account (or Azurite for local dev): https://docs.microsoft.com/azure/storage/common/storage-use-azurite
- Visual Studio 2022 or VS Code

### Flutter App
- Flutter SDK 3.16+: https://flutter.dev/docs/get-started/install
- Android Studio / Android SDK
- Java JDK 17+
- Android device or emulator (API 21+)

---

## Backend Setup

### 1. Clone/Download the Project
```bash
cd demoRabbitMQ
```

### 2. Install Azurite (Local Azure Storage Emulator)
```bash
npm install -g azurite
azurite --silent --location C:\azurite --debug C:\azurite\debug.log
```

### 3. Start RabbitMQ
```bash
# Windows (if installed as service)
net start RabbitMQ

# Or using Docker
docker run -d --name rabbitmq -p 5672:5672 -p 15672:15672 rabbitmq:3-management
```

### 4. Configure Connection Strings
Edit `ChatWithFiles.Api/appsettings.json`:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=ChatWithFiles;Trusted_Connection=True;TrustServerCertificate=True;"
  },
  "AzureBlob": {
    "ConnectionString": "DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://127.0.0.1:10000/devstoreaccount1;"
  },
  "RabbitMQ": {
    "ConnectionString": "amqp://guest:guest@localhost:5672"
  },
  "Auth": {
    "Authority": "https://your-auth-provider.com",
    "Audience": "chat-api"
  }
}
```

### 5. Create Database
```bash
# Run the SQL script
sqlcmd -S localhost -d master -i Database/Schema.sql
```

Or manually execute `Database/Schema.sql` in SQL Server Management Studio.

### 6. Run Database Migrations (if using EF Core migrations)
```bash
cd ChatWithFiles.Api
dotnet ef database update
```

### 7. Build and Run
```bash
# Build all projects
dotnet build

# Run the API
cd ChatWithFiles.Api
dotnet run

# Or with specific environment
dotnet run --environment Development
```

The API will be available at:
- **HTTPS**: https://localhost:5001
- **HTTP**: http://localhost:5000
- **Swagger**: https://localhost:5001/swagger
- **SignalR Hub**: https://localhost:5001/hubs/chat

---

## Flutter App Setup

### 1. Install Dependencies
```bash
cd FlutterApp
flutter pub get
```

### 2. Generate Database Code
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Configure API URL
Edit `lib/core/constants.dart`:
```dart
static const String baseUrl = 'https://YOUR_IP:5001'; // Use your machine's IP
```

For Android emulator, use `10.0.2.2` instead of `localhost`.

### 4. Run the App
```bash
# Check connected devices
flutter devices

# Run on connected device/emulator
flutter run

# Run in debug mode with verbose logging
flutter run -v

# Run in release mode
flutter run --release
```

### 5. Build APK
```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# App Bundle (for Play Store)
flutter build appbundle
```

---

## Configuration

### Backend Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ConnectionStrings__DefaultConnection` | SQL Server connection string | - |
| `AzureBlob__ConnectionString` | Azure Blob Storage connection string | - |
| `AzureBlob__ContainerName` | Container name for files | `chat-files` |
| `RabbitMQ__ConnectionString` | RabbitMQ connection string | `amqp://guest:guest@localhost:5672` |
| `Auth__Authority` | JWT Authority URL | - |
| `Auth__Audience` | JWT Audience | `chat-api` |

### Flutter Build Variants

```bash
# Development
flutter run --dart-define=API_BASE_URL=https://dev-api.example.com

# Staging
flutter run --dart-define=API_BASE_URL=https://staging-api.example.com

# Production
flutter run --dart-define=API_BASE_URL=https://api.example.com --release
```

---

## API Endpoints

### Messages

#### Create Message with File
```http
POST /api/v1/messages/with-file
Authorization: Bearer {token}
Content-Type: application/json

{
  "receiverId": "uuid",  // optional
  "groupId": "uuid",     // optional
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
      "expiresAt": "2024-01-01T12:00:00Z"
    }
  ]
}
```

#### Get Messages
```http
GET /api/v1/messages?userId=uuid&groupId=uuid&page=1&pageSize=50
Authorization: Bearer {token}
```

### Files

#### Confirm Upload
```http
POST /api/v1/files/{fileId}/confirm
Authorization: Bearer {token}
Content-Type: application/json

{
  "checksum": "optional-md5"
}
```

#### Get Download URL
```http
GET /api/v1/files/{fileId}/download-url
Authorization: Bearer {token}

Response:
{
  "downloadUrl": "https://storage...presigned-url",
  "expiresAt": "2024-01-01T12:00:00Z",
  "fileName": "photo.jpg",
  "fileSize": 1048576
}
```

#### Retry Failed Upload
```http
POST /api/v1/files/{fileId}/retry
Authorization: Bearer {token}
```

---

## SignalR Events

### Connection
```dart
// Connect to hub
await signalR.connect('https://localhost:5001/hubs/chat', accessToken);

// Join chat room
await signalR.joinChat('group_abc123');

// Leave chat room
await signalR.leaveChat('group_abc123');
```

### Server → Client Events

| Event | Description | Payload |
|-------|-------------|---------|
| `ReceiveMessage` | New message received | `ChatMessage` object |
| `FileUploadProgress` | Upload progress update | `{fileId, progress, status}` |
| `FileProcessingCompleted` | File processing done | `{fileId, thumbnailUrl, metadata}` |
| `FileError` | File error occurred | `{fileId, errorMessage, errorCode}` |
| `TypingIndicator` | User typing status | `{userId, userName, isTyping}` |
| `MessageStatusUpdate` | Message status changed | `{messageId, status}` |

### Client → Server Events

| Event | Description | Args |
|-------|-------------|------|
| `JoinChat` | Join chat room | `chatId` |
| `LeaveChat` | Leave chat room | `chatId` |
| `ReportUploadProgress` | Report upload progress | `fileId, progress, status` |
| `SendTypingIndicator` | Send typing status | `chatId, isTyping` |

---

## RabbitMQ Message Flow

### Queues

| Queue | Purpose | Consumer |
|-------|---------|----------|
| `file-processing` | Process uploaded files | `FileProcessingConsumer` |
| `file-processing-results` | Processing results | SignalR notifier |
| `file-processing-dlq` | Dead letters (failed) | Manual review |

### Message Types

#### FileUploadedEvent (Producer → file-processing)
```csharp
{
  "fileId": "uuid",
  "messageId": "uuid",
  "fileType": "image/jpeg",
  "storageKey": "chat-files/...",
  "fileSize": 1048576
}
```

#### Processing Flow
```
1. Client confirms upload → Backend publishes FileUploadedEvent
2. FileProcessingConsumer picks up message
3. Extract metadata (dimensions, duration)
4. Generate thumbnail (for images/videos)
5. Run antivirus scan (optional)
6. Publish result to file-processing-results
7. SignalR consumer notifies clients
```

---

## File Upload Flow

### End-to-End Process

```
1. User selects file in Flutter app
   ↓
2. App validates file (size, type)
   ↓
3. App calls POST /api/v1/messages/with-file
   ↓
4. Backend creates ChatMessage + FileAttachment records
   ↓
5. Backend generates presigned upload URL (expires in 1h)
   ↓
6. Backend returns messageId + uploadUrls
   ↓
7. App uploads file directly to Azure Blob using presigned URL
   - Progress tracked via Dio's onSendProgress
   - Updates UI with real-time percentage
   ↓
8. App calls POST /api/v1/files/{fileId}/confirm
   ↓
9. Backend verifies file exists in storage
   ↓
10. Backend publishes FileUploadedEvent to RabbitMQ
    ↓
11. Background consumer processes file:
    - Extract metadata
    - Generate thumbnail
    - Run antivirus scan
    ↓
12. Backend updates FileAttachment status via SignalR
    ↓
13. All clients in chat receive update with thumbnail URL
```

### Upload States in UI

```dart
// Pending: Show spinner
CircularProgressIndicator() + "Pending..."

// Uploading: Show progress bar
LinearProgressIndicator(value: progress/100) + "45%"

// Processing: Show processing indicator
CircularProgressIndicator() + "Processing..."

// Completed: Show checkmark + thumbnail
Icon(Icons.check_circle) + Image.network(thumbnailUrl)

// Failed: Show error + retry button
Icon(Icons.error) + "Error message" + ElevatedButton("Retry")
```

---

## Security

### File Validation
```csharp
// Allowed MIME types (whitelist)
- image/jpeg, image/png, image/gif, image/webp
- application/pdf, application/msword, etc.
- video/mp4, video/webm
- application/zip, etc.

// Max file size: 100 MB
// Validated at:
// 1. App level (before upload)
// 2. API level (when creating message)
// 3. Storage level (presigned URL constraints)
```

### Presigned URL Security
```csharp
// Upload URLs
- Expire in 1 hour
- Single-use (marked as used after upload)
- Restricted to Write/Create permissions
- Max file size enforced

// Download URLs
- Expire in 24 hours
- Read-only permissions
- Access control verified before generation
```

### Access Control
```csharp
// Only chat participants can:
// - View files in their messages
// - Download files
// - See upload progress

// Checked via:
// 1. JWT token validation
// 2. Message ownership verification
// 3. Group membership verification
```

### Android Permissions
```xml
<!-- Required permissions in AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
```

---

## Testing

### Backend Tests
```bash
# Run all tests
dotnet test

# Run with coverage
dotnet test /p:CollectCoverage=true

# Run specific test project
dotnet test ChatWithFiles.Application.Tests
```

### Flutter Tests
```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/upload_manager_test.dart
```

### Manual Testing Checklist

#### File Upload
- [ ] Upload image (JPEG, PNG) - success
- [ ] Upload PDF document - success
- [ ] Upload video (MP4) - success
- [ ] Upload file > 100 MB - should fail with error
- [ ] Upload unsupported file type - should fail with error
- [ ] Upload 3 files simultaneously - should queue properly
- [ ] Cancel upload mid-way - should cancel
- [ ] Retry failed upload - should work
- [ ] Disconnect during upload - should retry when reconnected
- [ ] Close app during upload - should resume on restart

#### Real-time Updates
- [ ] File upload progress visible in sender's chat
- [ ] Receiver sees file placeholder immediately
- [ ] Thumbnail appears after processing
- [ ] Error notification on failure
- [ ] Group chat: all members see updates

#### Offline Support
- [ ] Pending uploads persist after app restart
- [ ] Upload resumes when connection restored
- [ ] Cached messages available offline

---

## Troubleshooting

### Backend Issues

#### "Cannot connect to RabbitMQ"
```bash
# Check RabbitMQ status
rabbitmqctl status

# Restart RabbitMQ
net stop RabbitMQ
net start RabbitMQ
```

#### "Azure Storage connection failed"
```bash
# Verify Azurite is running
azurite --silent --location C:\azurite

# Test connection
curl http://127.0.0.1:10000/devstoreaccount1?comp=list
```

#### "SignalR connection fails"
- Ensure CORS is properly configured
- Check JWT token is valid and not expired
- Verify WebSocket is enabled in hosting environment

### Flutter Issues

#### "Connection refused" on Android Emulator
```dart
// Use 10.0.2.2 instead of localhost
static const String baseUrl = 'https://10.0.2.2:5001';
```

#### "Permission denied" when selecting files
```bash
# Ensure permissions are granted
flutter pub run permission_handler
```

#### "Build failed" after adding dependencies
```bash
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

#### "Upload not progressing"
- Check network connectivity
- Verify presigned URL hasn't expired
- Check backend logs for errors
- Ensure file size is within limits

---

## Production Deployment

### Backend
```bash
# Publish
dotnet publish -c Release -o ./publish

# Deploy to IIS/Azure/AWS
# Configure production appsettings.Production.json
# Set up HTTPS certificate
# Configure Redis for SignalR scale-out
# Set up CDN for file downloads
```

### Flutter
```bash
# Build release APK
flutter build apk --release --split-per-abi

# Build App Bundle
flutter build appbundle --release

# Sign APK
# Configure ProGuard rules
# Enable code shrinking
```

---

## Future Enhancements

- [ ] Chunked uploads for large files
- [ ] Pause/resume uploads
- [ ] Image compression before upload
- [ ] Video transcoding pipeline
- [ ] End-to-end encryption
- [ ] File search within chat
- [ ] File expiration policies
- [ ] Download analytics
- [ ] Advanced antivirus scanning

---

## License

This project is for educational and demonstration purposes.

---

## Support

For issues, questions, or contributions, please open an issue in the repository.
