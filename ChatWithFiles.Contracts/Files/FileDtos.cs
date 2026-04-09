namespace ChatWithFiles.Contracts.Files;

public record CreateFileAttachmentRequest(
    string FileName,
    long FileSize,
    string FileType
);

public record CreateMessageWithFileRequest(
    Guid? ReceiverId = null,
    Guid? GroupId = null,
    string? TextContent = null,
    List<CreateFileAttachmentRequest>? Files = null
);

public record FileUploadUrlResponse(
    Guid FileId,
    string UploadUrl,
    DateTime ExpiresAt
);

public record CreateMessageWithFileResponse(
    Guid MessageId,
    List<FileUploadUrlResponse> UploadUrls
);

public record ConfirmFileUploadRequest(
    string? Checksum = null
);

public record ConfirmFileUploadResponse(
    Guid FileId,
    string Status
);

public record FileDownloadUrlResponse(
    string DownloadUrl,
    DateTime ExpiresAt,
    string FileName,
    long FileSize
);

public record RetryFileUploadResponse(
    Guid FileId,
    string UploadUrl,
    DateTime ExpiresAt
);

public record FileAttachmentDto(
    Guid Id,
    string FileName,
    string OriginalFileName,
    string FileType,
    string FileExtension,
    long FileSize,
    string UploadStatus,
    int UploadProgress,
    string? ThumbnailUrl,
    bool IsScanned,
    string? ScanStatus,
    int? Width,
    int? Height,
    int? Duration,
    string? ErrorMessage,
    DateTime CreatedAt
);
