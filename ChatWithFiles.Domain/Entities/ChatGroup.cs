using ChatWithFiles.Domain.Common;

namespace ChatWithFiles.Domain.Entities;

public class ChatGroup : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? AvatarUrl { get; set; }
    public Guid CreatedBy { get; set; }
    public bool IsActive { get; set; } = true;
    
    // Navigation properties
    public User? Creator { get; set; }
    public ICollection<ChatGroupMember> Members { get; set; } = new List<ChatGroupMember>();
    public ICollection<ChatMessage> Messages { get; set; } = new List<ChatMessage>();
}
