using ChatWithFiles.Domain.Common;
using ChatWithFiles.Domain.Enums;

namespace ChatWithFiles.Domain.Entities;

public class FileAttachment : BaseEntity
{
    public Guid MessageId { get; set; }
    
    // File info
    public string FileName { get; set; } = string.Empty;
    public string OriginalFileName { get; set; } = string.Empty;
    public string FileType { get; set; } = string.Empty; // MIME type
    public string FileExtension { get; set; } = string.Empty;
    public long FileSize { get; set; }
    
    // Storage
    public string StorageKey { get; set; } = string.Empty;
    public StorageProvider StorageProvider { get; set; } = StorageProvider.AzureBlob;
    public string? StorageRegion { get; set; }
    
    // Upload tracking
    public UploadStatus UploadStatus { get; set; } = UploadStatus.Pending;
    public int UploadProgress { get; set; }
    public DateTime? UploadStartedAt { get; set; }
    public DateTime? UploadCompletedAt { get; set; }
    
    // Post-processing
    public ProcessingStatus ProcessingStatus { get; set; } = ProcessingStatus.Pending;
    public string? ThumbnailUrl { get; set; }
    public bool IsScanned { get; set; }
    public ScanStatus? ScanStatus { get; set; }
    public string? ScanResult { get; set; }
    public DateTime? ScannedAt { get; set; }
    
    // File metadata
    public int? Width { get; set; }
    public int? Height { get; set; }
    public int? Duration { get; set; } // seconds
    public int? BitRate { get; set; }
    public double? FrameRate { get; set; }
    
    // Error handling
    public string? ErrorMessage { get; set; }
    public string? ErrorCode { get; set; }
    public int RetryCount { get; set; }
    public int MaxRetries { get; set; } = 3;
    
    // Audit
    public Guid UploadedBy { get; set; }
    
    // Navigation properties
    public ChatMessage? Message { get; set; }
    public User? Uploader { get; set; }
    public ICollection<UploadSession> UploadSessions { get; set; } = new List<UploadSession>();
    
    // Helper methods
    public void UpdateProgress(int progress, UploadStatus status)
    {
        UploadProgress = progress;
        UploadStatus = status;
        UpdatedAt = DateTime.UtcNow;
        
        if (status == UploadStatus.Uploading && UploadStartedAt == null)
        {
            UploadStartedAt = DateTime.UtcNow;
        }
    }
    
    public void MarkAsUploaded(string storageKey, long fileSize)
    {
        UploadStatus = UploadStatus.Uploaded;
        UploadProgress = 100;
        UploadCompletedAt = DateTime.UtcNow;
        ProcessingStatus = ProcessingStatus.Pending;
        StorageKey = storageKey;
        FileSize = fileSize;
        UpdatedAt = DateTime.UtcNow;
    }
    
    public void MarkAsProcessing()
    {
        ProcessingStatus = ProcessingStatus.InProgress;
        UpdatedAt = DateTime.UtcNow;
    }
    
    public void MarkProcessingCompleted(string? thumbnailUrl = null)
    {
        ProcessingStatus = ProcessingStatus.Completed;
        ThumbnailUrl = thumbnailUrl;
        UpdatedAt = DateTime.UtcNow;
    }
    
    public void MarkProcessingFailed(string error, string? errorCode = null)
    {
        ProcessingStatus = ProcessingStatus.Failed;
        ErrorMessage = error;
        ErrorCode = errorCode;
        RetryCount++;
        UpdatedAt = DateTime.UtcNow;
    }
    
    public void MarkScanned(ScanStatus status, string? result = null)
    {
        IsScanned = true;
        ScanStatus = status;
        ScanResult = result;
        ScannedAt = DateTime.UtcNow;
        UpdatedAt = DateTime.UtcNow;
    }
    
    public bool CanRetry() => RetryCount < MaxRetries;
    
    public void PrepareForRetry()
    {
        UploadStatus = UploadStatus.Pending;
        UploadProgress = 0;
        ProcessingStatus = ProcessingStatus.Pending;
        UpdatedAt = DateTime.UtcNow;
    }
}
