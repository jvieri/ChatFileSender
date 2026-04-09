-- =============================================
-- Chat with File Sharing - Database Schema
-- SQL Server 2019+
-- =============================================

-- Users
CREATE TABLE Users (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    Username NVARCHAR(100) NOT NULL UNIQUE,
    Email NVARCHAR(255) NOT NULL UNIQUE,
    DisplayName NVARCHAR(200) NULL,
    AvatarUrl NVARCHAR(500) NULL,
    IsActive BIT DEFAULT 1,
    CreatedAt DATETIME2 DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2 NULL,
    
    INDEX IX_Users_Username (Username),
    INDEX IX_Users_Email (Email)
);

-- Chat Groups
CREATE TABLE ChatGroups (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    Name NVARCHAR(200) NOT NULL,
    Description NVARCHAR(500) NULL,
    AvatarUrl NVARCHAR(500) NULL,
    CreatedBy UNIQUEIDENTIFIER REFERENCES Users(Id),
    IsActive BIT DEFAULT 1,
    CreatedAt DATETIME2 DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2 NULL,
    
    INDEX IX_Groups_CreatedBy (CreatedBy)
);

-- Group Members
CREATE TABLE ChatGroupMembers (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    GroupId UNIQUEIDENTIFIER NOT NULL REFERENCES ChatGroups(Id) ON DELETE CASCADE,
    UserId UNIQUEIDENTIFIER NOT NULL REFERENCES Users(Id),
    Role VARCHAR(20) DEFAULT 'Member', -- Admin, Moderator, Member
    JoinedAt DATETIME2 DEFAULT SYSUTCDATETIME(),
    LeftAt DATETIME2 NULL,
    
    CONSTRAINT UQ_GroupMember UNIQUE(GroupId, UserId),
    INDEX IX_Members_Group (GroupId),
    INDEX IX_Members_User (UserId)
);

-- Chat Messages
CREATE TABLE ChatMessages (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    SenderId UNIQUEIDENTIFIER NOT NULL REFERENCES Users(Id),
    GroupId UNIQUEIDENTIFIER NULL REFERENCES ChatGroups(Id),
    ReceiverId UNIQUEIDENTIFIER NULL REFERENCES Users(Id),
    TextContent NVARCHAR(MAX) NULL,
    MessageType VARCHAR(20) DEFAULT 'Text', -- Text, File, System, Image, Video
    Status VARCHAR(20) DEFAULT 'Sent', -- Sent, Delivered, Read, Deleted
    
    -- Metadata
    IpAddress NVARCHAR(45) NULL,
    UserAgent NVARCHAR(500) NULL,
    
    CreatedAt DATETIME2 DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2 NULL,
    DeletedAt DATETIME2 NULL,
    
    -- Indexes for performance
    INDEX IX_Messages_User_Receiver (ReceiverId, CreatedAt DESC),
    INDEX IX_Messages_Group (GroupId, CreatedAt DESC),
    INDEX IX_Messages_Sender (SenderId, CreatedAt DESC),
    INDEX IX_Messages_Type (MessageType),
    
    -- Constraint: either GroupId or ReceiverId must be set, not both
    CONSTRAINT CK_Message_Target CHECK (
        (GroupId IS NOT NULL AND ReceiverId IS NULL) OR
        (GroupId IS NULL AND ReceiverId IS NOT NULL)
    )
);

-- File Attachments
CREATE TABLE FileAttachments (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    MessageId UNIQUEIDENTIFIER NOT NULL REFERENCES ChatMessages(Id) ON DELETE CASCADE,
    
    -- File info
    FileName NVARCHAR(255) NOT NULL,
    OriginalFileName NVARCHAR(255) NOT NULL,
    FileType VARCHAR(100) NOT NULL, -- MIME type
    FileExtension VARCHAR(10) NOT NULL,
    FileSize BIGINT NOT NULL, -- bytes
    
    -- Storage
    StorageKey NVARCHAR(500) NOT NULL, -- S3/Blob key
    StorageProvider VARCHAR(20) DEFAULT 'AzureBlob', -- AzureBlob, S3, Local
    StorageRegion VARCHAR(50) NULL, -- Azure region or S3 bucket
    
    -- Upload tracking
    UploadStatus VARCHAR(20) DEFAULT 'Pending', 
    -- Pending, Uploading, Uploaded, Processing, Completed, Failed, Cancelled
    UploadProgress INT DEFAULT 0, -- 0-100
    UploadStartedAt DATETIME2 NULL,
    UploadCompletedAt DATETIME2 NULL,
    
    -- Post-processing
    ProcessingStatus VARCHAR(20) DEFAULT 'Pending', 
    -- Pending, InProgress, Completed, Failed, Skipped
    ThumbnailUrl NVARCHAR(500) NULL,
    IsScanned BIT DEFAULT 0,
    ScanStatus VARCHAR(20) NULL, -- Clean, Infected, Suspicious, Skipped
    ScanResult NVARCHAR(MAX) NULL,
    ScannedAt DATETIME2 NULL,
    
    -- File metadata
    Width INT NULL, -- for images/videos
    Height INT NULL,
    Duration INT NULL, -- seconds for videos/audio
    BitRate INT NULL,
    FrameRate FLOAT NULL,
    
    -- Error handling
    ErrorMessage NVARCHAR(MAX) NULL,
    ErrorCode VARCHAR(50) NULL,
    RetryCount INT DEFAULT 0,
    MaxRetries INT DEFAULT 3,
    
    -- Audit
    UploadedBy UNIQUEIDENTIFIER NOT NULL REFERENCES Users(Id),
    CreatedAt DATETIME2 DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2 NULL,
    DeletedAt DATETIME2 NULL,
    
    -- Indexes
    INDEX IX_Files_Message (MessageId),
    INDEX IX_Files_UploadStatus (UploadStatus),
    INDEX IX_Files_ProcessingStatus (ProcessingStatus),
    INDEX IX_Files_ScanStatus (ScanStatus),
    INDEX IX_Files_StorageKey (StorageKey),
    INDEX IX_Files_CreatedAt (CreatedAt DESC)
);

-- Upload Sessions (for resumable uploads)
CREATE TABLE UploadSessions (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    FileAttachmentId UNIQUEIDENTIFIER NOT NULL REFERENCES FileAttachments(Id) ON DELETE CASCADE,
    UserId UNIQUEIDENTIFIER NOT NULL REFERENCES Users(Id),
    
    -- Presigned URL
    PresignedUrl NVARCHAR(1000) NOT NULL,
    PresignedUrlExpiresAt DATETIME2 NOT NULL,
    PresignedUrlUsed BIT DEFAULT 0,
    
    -- Session tracking
    SessionStatus VARCHAR(20) DEFAULT 'Active', 
    -- Active, Completed, Expired, Cancelled, Failed
    
    -- Chunked upload support (optional)
    TotalChunks INT NULL,
    UploadedChunks INT DEFAULT 0,
    ChunkSize INT NULL, -- bytes
    
    -- Audit
    CreatedAt DATETIME2 DEFAULT SYSUTCDATETIME(),
    CompletedAt DATETIME2 NULL,
    
    INDEX IX_Sessions_File (FileAttachmentId),
    INDEX IX_Sessions_User (UserId),
    INDEX IX_Sessions_Status_Expires (SessionStatus, PresignedUrlExpiresAt),
    INDEX IX_Sessions_Expires (PresignedUrlExpiresAt)
);

-- Download Access Log (for auditing)
CREATE TABLE FileDownloadLogs (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    FileAttachmentId UNIQUEIDENTIFIER NOT NULL REFERENCES FileAttachments(Id),
    UserId UNIQUEIDENTIFIER NOT NULL REFERENCES Users(Id),
    DownloadedAt DATETIME2 DEFAULT SYSUTCDATETIME(),
    IpAddress NVARCHAR(45) NULL,
    UserAgent NVARCHAR(500) NULL,
    
    INDEX IX_Downloads_File (FileAttachmentId, DownloadedAt DESC),
    INDEX IX_Downloads_User (UserId, DownloadedAt DESC)
);

-- =============================================
-- Stored Procedures
-- =============================================

-- Create message with file attachment
CREATE PROCEDURE usp_CreateMessageWithFile
    @SenderId UNIQUEIDENTIFIER,
    @ReceiverId UNIQUEIDENTIFIER = NULL,
    @GroupId UNIQUEIDENTIFIER = NULL,
    @TextContent NVARCHAR(MAX) = NULL,
    @MessageType VARCHAR(20) = 'File',
    @FileId UNIQUEIDENTIFIER OUTPUT,
    @MessageId UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Create message
        SET @MessageId = NEWID();
        INSERT INTO ChatMessages (Id, SenderId, ReceiverId, GroupId, TextContent, MessageType)
        VALUES (@MessageId, @SenderId, @ReceiverId, @GroupId, @TextContent, @MessageType);
        
        -- Create file attachment placeholder
        SET @FileId = NEWID();
        INSERT INTO FileAttachments (Id, MessageId, FileName, OriginalFileName, FileType, 
                                      FileExtension, FileSize, StorageKey, UploadStatus, UploadedBy)
        VALUES (@FileId, @MessageId, '', '', '', '', 0, '', 'Pending', @SenderId);
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

-- Get files for a message
CREATE PROCEDURE usp_GetFilesByMessageId
    @MessageId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        Id, FileName, OriginalFileName, FileType, FileExtension, FileSize,
        StorageProvider, UploadStatus, UploadProgress, ThumbnailUrl,
        IsScanned, ScanStatus, Width, Height, Duration, ErrorMessage,
        CreatedAt, UpdatedAt
    FROM FileAttachments
    WHERE MessageId = @MessageId
    ORDER BY CreatedAt;
END;

-- Update file upload progress
CREATE PROCEDURE usp_UpdateFileUploadProgress
    @FileId UNIQUEIDENTIFIER,
    @Progress INT,
    @Status VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE FileAttachments
    SET UploadProgress = @Progress,
        UploadStatus = @Status,
        UpdatedAt = SYSUTCDATETIME()
    WHERE Id = @FileId;
END;

-- Complete file upload
CREATE PROCEDURE usp_CompleteFileUpload
    @FileId UNIQUEIDENTIFIER,
    @StorageKey NVARCHAR(500),
    @FileSize BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE FileAttachments
    SET UploadStatus = 'Uploaded',
        UploadProgress = 100,
        UploadCompletedAt = SYSUTCDATETIME(),
        ProcessingStatus = 'Pending',
        StorageKey = @StorageKey,
        FileSize = @FileSize,
        UpdatedAt = SYSUTCDATETIME()
    WHERE Id = @FileId;
END;

-- Get pending uploads for retry
CREATE PROCEDURE usp_GetPendingUploads
    @MaxAgeHours INT = 24
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        fa.Id, fa.MessageId, fa.UploadedBy, fa.FileName, fa.FileSize,
        fa.RetryCount, fa.MaxRetries, fa.CreatedAt,
        us.PresignedUrl, us.PresignedUrlExpiresAt
    FROM FileAttachments fa
    INNER JOIN UploadSessions us ON fa.Id = us.FileAttachmentId
    WHERE fa.UploadStatus IN ('Pending', 'Uploading', 'Failed')
      AND fa.RetryCount < fa.MaxRetries
      AND fa.CreatedAt >= DATEADD(HOUR, -@MaxAgeHours, SYSUTCDATETIME())
    ORDER BY fa.CreatedAt;
END;

-- =============================================
-- Indexes for common queries
-- =============================================

-- Get recent messages for user
CREATE INDEX IX_Messages_UserRecent 
ON ChatMessages(ReceiverId, CreatedAt DESC) 
INCLUDE (SenderId, TextContent, MessageType, Status);

-- Get recent messages for group
CREATE INDEX IX_Messages_GroupRecent 
ON ChatMessages(GroupId, CreatedAt DESC) 
INCLUDE (SenderId, TextContent, MessageType, Status);

-- Get user's active groups
CREATE INDEX IX_Members_UserActive 
ON ChatGroupMembers(UserId, JoinedAt DESC) 
INCLUDE (GroupId, Role)
WHERE LeftAt IS NULL;
