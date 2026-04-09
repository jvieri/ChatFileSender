namespace ChatWithFiles.Domain.Enums;

public enum UploadStatus
{
    Pending = 0,
    Uploading = 1,
    Uploaded = 2,
    Processing = 3,
    Completed = 4,
    Failed = 5,
    Cancelled = 6
}

public enum ProcessingStatus
{
    Pending = 0,
    InProgress = 1,
    Completed = 2,
    Failed = 3,
    Skipped = 4
}

public enum ScanStatus
{
    Clean = 0,
    Infected = 1,
    Suspicious = 2,
    Skipped = 3
}

public enum MessageType
{
    Text = 0,
    File = 1,
    Image = 2,
    Video = 3,
    System = 4
}

public enum MessageStatus
{
    Sent = 0,
    Delivered = 1,
    Read = 2,
    Deleted = 3
}

public enum StorageProvider
{
    AzureBlob = 0,
    S3 = 1,
    Local = 2
}

public enum SessionStatus
{
    Active = 0,
    Completed = 1,
    Expired = 2,
    Cancelled = 3,
    Failed = 4
}
