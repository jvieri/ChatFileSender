using ChatWithFiles.Domain.Common;

namespace ChatWithFiles.Domain.Entities;

public class ChatGroupMember : BaseEntity
{
    public Guid GroupId { get; set; }
    public Guid UserId { get; set; }
    public string Role { get; set; } = "Member"; // Admin, Moderator, Member
    public DateTime JoinedAt { get; set; } = DateTime.UtcNow;
    public DateTime? LeftAt { get; set; }
    
    // Navigation properties
    public ChatGroup? Group { get; set; }
    public User? User { get; set; }
}
