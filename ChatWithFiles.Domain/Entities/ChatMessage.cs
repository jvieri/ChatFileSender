using ChatWithFiles.Domain.Common;
using ChatWithFiles.Domain.Enums;

namespace ChatWithFiles.Domain.Entities;

public class ChatMessage : BaseEntity
{
    public Guid SenderId { get; set; }
    public Guid? GroupId { get; set; }
    public Guid? ReceiverId { get; set; }
    public string? TextContent { get; set; }
    public MessageType MessageType { get; set; } = MessageType.Text;
    public MessageStatus Status { get; set; } = MessageStatus.Sent;
    
    // Metadata
    public string? IpAddress { get; set; }
    public string? UserAgent { get; set; }
    
    // Navigation properties
    public User? Sender { get; set; }
    public User? Receiver { get; set; }
    public ChatGroup? Group { get; set; }
    public ICollection<FileAttachment> Attachments { get; set; } = new List<FileAttachment>();
    
    // Helper methods
    public bool IsGroupMessage() => GroupId.HasValue;
    public bool IsDirectMessage() => ReceiverId.HasValue;
    
    public void MarkAsDelivered()
    {
        Status = MessageStatus.Delivered;
        UpdatedAt = DateTime.UtcNow;
    }
    
    public void MarkAsRead()
    {
        Status = MessageStatus.Read;
        UpdatedAt = DateTime.UtcNow;
    }
}
