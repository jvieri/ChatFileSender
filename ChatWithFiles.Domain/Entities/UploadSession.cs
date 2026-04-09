using ChatWithFiles.Domain.Common;
using ChatWithFiles.Domain.Enums;

namespace ChatWithFiles.Domain.Entities;

public class UploadSession : BaseEntity
{
    public Guid FileAttachmentId { get; set; }
    public Guid UserId { get; set; }
    
    // Presigned URL
    public string PresignedUrl { get; set; } = string.Empty;
    public DateTime PresignedUrlExpiresAt { get; set; }
    public bool PresignedUrlUsed { get; set; }
    
    // Session tracking
    public SessionStatus SessionStatus { get; set; } = SessionStatus.Active;
    public DateTime? CompletedAt { get; set; }

    // Chunked upload support (optional)
    public int? TotalChunks { get; set; }
    public int UploadedChunks { get; set; }
    public int? ChunkSize { get; set; }
    
    // Navigation properties
    public FileAttachment? FileAttachment { get; set; }
    public User? User { get; set; }
    
    // Helper methods
    public void MarkAsUsed()
    {
        PresignedUrlUsed = true;
        UpdatedAt = DateTime.UtcNow;
    }
    
    public void MarkAsCompleted()
    {
        SessionStatus = SessionStatus.Completed;
        CompletedAt = DateTime.UtcNow;
        UpdatedAt = DateTime.UtcNow;
    }
    
    public void MarkAsExpired()
    {
        SessionStatus = SessionStatus.Expired;
        UpdatedAt = DateTime.UtcNow;
    }
    
    public bool IsExpired() => PresignedUrlExpiresAt < DateTime.UtcNow;
    public bool IsActive() => SessionStatus == SessionStatus.Active && !IsExpired();
}
