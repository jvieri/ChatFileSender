using ChatWithFiles.Domain.Entities;
using ChatWithFiles.Domain.Enums;

namespace ChatWithFiles.Domain.Interfaces;

public interface IChatMessageRepository
{
    Task<ChatMessage?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<ChatMessage> CreateAsync(ChatMessage message, CancellationToken ct = default);
    Task UpdateAsync(ChatMessage message, CancellationToken ct = default);
    
    Task<List<ChatMessage>> GetDirectMessagesAsync(Guid userId1, Guid userId2, int page, int pageSize, CancellationToken ct = default);
    Task<List<ChatMessage>> GetGroupMessagesAsync(Guid groupId, int page, int pageSize, CancellationToken ct = default);
    Task<List<ChatMessage>> GetRecentMessagesAsync(Guid? userId, Guid? groupId, int count, CancellationToken ct = default);
}

public interface IFileAttachmentRepository
{
    Task<FileAttachment?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<List<FileAttachment>> GetByMessageIdAsync(Guid messageId, CancellationToken ct = default);
    Task<FileAttachment> CreateAsync(FileAttachment attachment, CancellationToken ct = default);
    Task UpdateAsync(FileAttachment attachment, CancellationToken ct = default);
    
    Task UpdateUploadProgressAsync(Guid fileId, int progress, UploadStatus status, CancellationToken ct = default);
    Task MarkAsUploadedAsync(Guid fileId, string storageKey, long fileSize, CancellationToken ct = default);
    Task<List<FileAttachment>> GetFailedUploadsAsync(int maxRetries, TimeSpan maxAge, CancellationToken ct = default);
}

public interface IUploadSessionRepository
{
    Task<UploadSession?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<UploadSession> CreateAsync(UploadSession session, CancellationToken ct = default);
    Task UpdateAsync(UploadSession session, CancellationToken ct = default);
    Task<List<UploadSession>> GetExpiredSessionsAsync(CancellationToken ct = default);
}

public interface IUserRepository
{
    Task<User?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<User?> GetByUsernameAsync(string username, CancellationToken ct = default);
    Task<List<User>> GetActiveUsersAsync(CancellationToken ct = default);
}

public interface IChatGroupRepository
{
    Task<ChatGroup?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<List<ChatGroup>> GetUserGroupsAsync(Guid userId, CancellationToken ct = default);
    Task<bool> IsMemberAsync(Guid groupId, Guid userId, CancellationToken ct = default);
    Task<List<Guid>> GetGroupMemberIdsAsync(Guid groupId, CancellationToken ct = default);
}

public interface IUnitOfWork
{
    Task<int> SaveChangesAsync(CancellationToken ct = default);
    Task BeginTransactionAsync(CancellationToken ct = default);
    Task CommitTransactionAsync(CancellationToken ct = default);
    Task RollbackTransactionAsync(CancellationToken ct = default);
}
