using ChatWithFiles.Domain.Entities;

namespace ChatWithFiles.Domain.Interfaces;

public interface IStorageService
{
    Task<string> GenerateUploadUrlAsync(string storageKey, TimeSpan expiration, long maxSize, CancellationToken ct = default);
    Task<string> GenerateDownloadUrlAsync(string storageKey, TimeSpan expiration, CancellationToken ct = default);
    Task<bool> FileExistsAsync(string storageKey, CancellationToken ct = default);
    Task DeleteFileAsync(string storageKey, CancellationToken ct = default);
    Task<Dictionary<string, object>> GetFileMetadataAsync(string storageKey, CancellationToken ct = default);
}

public interface IFileValidationService
{
    bool IsValidFileType(string mimeType, string extension);
    bool IsValidFileSize(long size);
    Task<FileMetadata> ValidateFileAsync(Stream fileStream, string mimeType, CancellationToken ct = default);
}

public record FileMetadata(
    int? Width,
    int? Height,
    int? Duration,
    int? BitRate,
    double? FrameRate
);

public interface IMessageBus
{
    Task PublishAsync<T>(T message, string queueName, CancellationToken ct = default) where T : class;
    Task PublishAsync<T>(T message, Dictionary<string, object> headers, string queueName, CancellationToken ct = default) where T : class;
}

public interface IChatHubService
{
    Task NotifyNewMessageAsync(string chatId, object message);
    Task NotifyFileUploadProgressAsync(string userId, Guid fileId, int progress, string status);
    Task NotifyFileProcessingCompletedAsync(string chatId, Guid fileId, object metadata);
    Task NotifyFileProcessingFailedAsync(string chatId, Guid fileId, string error, string? errorCode);
    Task NotifyMessageStatusAsync(string userId, Guid messageId, string status);
    Task NotifyTypingIndicatorAsync(string chatId, Guid userId, string userName, bool isTyping);
}

public interface ICurrentUserAccessor
{
    Guid UserId { get; }
    string UserName { get; }
    string Email { get; }
}
