using ChatWithFiles.Domain.Common;

namespace ChatWithFiles.Domain.Entities;

public class User : BaseEntity
{
    public string Username { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? DisplayName { get; set; }
    public string? AvatarUrl { get; set; }
    public bool IsActive { get; set; } = true;
    
    // Navigation properties
    public ICollection<ChatMessage> SentMessages { get; set; } = new List<ChatMessage>();
    public ICollection<ChatMessage> ReceivedMessages { get; set; } = new List<ChatMessage>();
    public ICollection<ChatGroup> CreatedGroups { get; set; } = new List<ChatGroup>();
    public ICollection<ChatGroupMember> GroupMemberships { get; set; } = new List<ChatGroupMember>();
    public ICollection<FileAttachment> UploadedFiles { get; set; } = new List<FileAttachment>();
}
