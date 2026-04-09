using Microsoft.EntityFrameworkCore;
using ChatWithFiles.Domain.Entities;

namespace ChatWithFiles.Infrastructure.Persistence;

public class ChatDbContext : DbContext
{
    public ChatDbContext(DbContextOptions<ChatDbContext> options) : base(options)
    {
    }
    
    public DbSet<User> Users => Set<User>();
    public DbSet<ChatGroup> ChatGroups => Set<ChatGroup>();
    public DbSet<ChatGroupMember> ChatGroupMembers => Set<ChatGroupMember>();
    public DbSet<ChatWithFiles.Domain.Entities.ChatMessage> ChatMessages => Set<ChatWithFiles.Domain.Entities.ChatMessage>();
    public DbSet<FileAttachment> FileAttachments => Set<FileAttachment>();
    public DbSet<UploadSession> UploadSessions => Set<UploadSession>();
    
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        
        // User configuration
        modelBuilder.Entity<User>(entity =>
        {
            entity.HasIndex(u => u.Username).IsUnique();
            entity.HasIndex(u => u.Email).IsUnique();
        });
        
        // ChatGroup configuration
        modelBuilder.Entity<ChatGroup>(entity =>
        {
            entity.HasOne<User>()
                .WithMany(u => u.CreatedGroups)
                .HasForeignKey(g => g.CreatedBy)
                .OnDelete(DeleteBehavior.Restrict);
        });
        
        // ChatGroupMember configuration
        modelBuilder.Entity<ChatGroupMember>(entity =>
        {
            entity.HasIndex(m => new { m.GroupId, m.UserId }).IsUnique();
            
            entity.HasOne<ChatGroup>()
                .WithMany(g => g.Members)
                .HasForeignKey(m => m.GroupId)
                .OnDelete(DeleteBehavior.Cascade);
            
            entity.HasOne<User>()
                .WithMany(u => u.GroupMemberships)
                .HasForeignKey(m => m.UserId)
                .OnDelete(DeleteBehavior.Restrict);
        });
        
        // ChatMessage configuration
        modelBuilder.Entity<ChatWithFiles.Domain.Entities.ChatMessage>(entity =>
        {
            entity.HasIndex(m => new { m.ReceiverId, m.CreatedAt });
            entity.HasIndex(m => new { m.GroupId, m.CreatedAt });
            entity.HasIndex(m => m.MessageType);
            
            entity.HasOne<User>()
                .WithMany(u => u.SentMessages)
                .HasForeignKey(m => m.SenderId)
                .OnDelete(DeleteBehavior.Restrict);
            
            entity.HasOne<User>()
                .WithMany(u => u.ReceivedMessages)
                .HasForeignKey(m => m.ReceiverId)
                .OnDelete(DeleteBehavior.Restrict);
            
            entity.HasOne<ChatGroup>()
                .WithMany(g => g.Messages)
                .HasForeignKey(m => m.GroupId)
                .OnDelete(DeleteBehavior.Restrict);
            
            // Constraint: either GroupId or ReceiverId must be set
            entity.HasCheckConstraint("CK_Message_Target", 
                "(GroupId IS NOT NULL AND ReceiverId IS NULL) OR (GroupId IS NULL AND ReceiverId IS NOT NULL)");
        });
        
        // FileAttachment configuration
        modelBuilder.Entity<FileAttachment>(entity =>
        {
            entity.HasIndex(f => f.MessageId);
            entity.HasIndex(f => f.UploadStatus);
            entity.HasIndex(f => f.ProcessingStatus);
            entity.HasIndex(f => f.StorageKey);
            entity.HasIndex(f => f.CreatedAt);
            
            entity.HasOne<ChatWithFiles.Domain.Entities.ChatMessage>()
                .WithMany(m => m.Attachments)
                .HasForeignKey(f => f.MessageId)
                .OnDelete(DeleteBehavior.Cascade);
            
            entity.HasOne<User>()
                .WithMany(u => u.UploadedFiles)
                .HasForeignKey(f => f.UploadedBy)
                .OnDelete(DeleteBehavior.Restrict);
        });
        
        // UploadSession configuration
        modelBuilder.Entity<UploadSession>(entity =>
        {
            entity.HasIndex(s => s.FileAttachmentId);
            entity.HasIndex(s => s.UserId);
            entity.HasIndex(s => new { s.SessionStatus, s.PresignedUrlExpiresAt });
            
            entity.HasOne<FileAttachment>()
                .WithMany(a => a.UploadSessions)
                .HasForeignKey(s => s.FileAttachmentId)
                .OnDelete(DeleteBehavior.Cascade);
            
            entity.HasOne<User>()
                .WithMany()
                .HasForeignKey(s => s.UserId)
                .OnDelete(DeleteBehavior.Restrict);
        });
    }
}
