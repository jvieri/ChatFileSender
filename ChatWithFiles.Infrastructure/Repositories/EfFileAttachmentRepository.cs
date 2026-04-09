using ChatWithFiles.Domain.Entities;
using ChatWithFiles.Domain.Enums;
using ChatWithFiles.Domain.Interfaces;
using ChatWithFiles.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace ChatWithFiles.Infrastructure.Repositories;

public class EfFileAttachmentRepository : EfRepository<FileAttachment>, IFileAttachmentRepository
{
    public EfFileAttachmentRepository(ChatDbContext context) : base(context)
    {
    }
    
    public async Task<List<FileAttachment>> GetByMessageIdAsync(Guid messageId, CancellationToken ct = default)
    {
        return await _context.FileAttachments
            .Where(f => f.MessageId == messageId)
            .OrderBy(f => f.CreatedAt)
            .ToListAsync(ct);
    }
    
    public async Task UpdateUploadProgressAsync(Guid fileId, int progress, UploadStatus status, CancellationToken ct = default)
    {
        var file = await _context.FileAttachments.FindAsync(new object[] { fileId }, cancellationToken: ct);
        if (file != null)
        {
            file.UpdateProgress(progress, status);
            await _context.SaveChangesAsync(ct);
        }
    }
    
    public async Task MarkAsUploadedAsync(Guid fileId, string storageKey, long fileSize, CancellationToken ct = default)
    {
        var file = await _context.FileAttachments.FindAsync(new object[] { fileId }, cancellationToken: ct);
        if (file != null)
        {
            file.MarkAsUploaded(storageKey, fileSize);
            await _context.SaveChangesAsync(ct);
        }
    }
    
    public async Task<List<FileAttachment>> GetFailedUploadsAsync(int maxRetries, TimeSpan maxAge, CancellationToken ct = default)
    {
        var cutoffDate = DateTime.UtcNow.Subtract(maxAge);
        
        return await _context.FileAttachments
            .Include(f => f.Message)
            .Where(f => (f.UploadStatus == UploadStatus.Pending || 
                         f.UploadStatus == UploadStatus.Uploading || 
                         f.UploadStatus == UploadStatus.Failed) &&
                        f.RetryCount < maxRetries &&
                        f.CreatedAt >= cutoffDate)
            .OrderBy(f => f.CreatedAt)
            .ToListAsync(ct);
    }
}
