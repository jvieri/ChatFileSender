namespace ChatWithFiles.Contracts.SignalR;

public record FileUploadProgressEvent(
    Guid FileId,
    Guid MessageId,
    int Progress,
    string Status
);

public record FileProcessingCompletedEvent(
    Guid FileId,
    Guid MessageId,
    string? ThumbnailUrl,
    int? Width,
    int? Height,
    int? Duration
);

public record FileProcessingFailedEvent(
    Guid FileId,
    Guid MessageId,
    string ErrorMessage,
    string? ErrorCode
);

public record NewMessageEvent(
    Guid MessageId,
    Guid SenderId,
    string SenderName,
    Guid? ReceiverId,
    Guid? GroupId,
    string? TextContent,
    string MessageType,
    List<FileAttachmentBriefDto> Files,
    DateTime CreatedAt
);

public record FileAttachmentBriefDto(
    Guid FileId,
    string FileName,
    string FileType,
    long FileSize,
    string UploadStatus,
    int UploadProgress,
    string? ThumbnailUrl
);

public record MessageStatusUpdateEvent(
    Guid MessageId,
    string Status
);

public record TypingIndicatorEvent(
    Guid UserId,
    string UserName,
    Guid? GroupId,
    bool IsTyping
);
