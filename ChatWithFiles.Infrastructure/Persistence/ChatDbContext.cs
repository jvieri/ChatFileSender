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
    public DbSet<ChatMessage> ChatMessages => Set<ChatMessage>();
    public DbSet<FileAttachment> FileAttachments => Set<FileAttachment>();
    public DbSet<UploadSession> UploadSessions => Set<UploadSession>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // ── User ────────────────────────────────────────────────────────────
        modelBuilder.Entity<User>(entity =>
        {
            entity.HasIndex(u => u.Username).IsUnique();
            entity.HasIndex(u => u.Email).IsUnique();
        });

        // ── ChatGroup ────────────────────────────────────────────────────────
        modelBuilder.Entity<ChatGroup>(entity =>
        {
            entity.HasOne<User>()
                  .WithMany(u => u.CreatedGroups)
                  .HasForeignKey(g => g.CreatedBy)
                  .OnDelete(DeleteBehavior.Restrict);
        });

        // ── ChatGroupMember ──────────────────────────────────────────────────
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

        // ── ChatMessage ──────────────────────────────────────────────────────
        // Use explicit navigation-property references so EF doesn't create
        // shadow FK columns (GroupId1, ReceiverId1, SenderId1).
        modelBuilder.Entity<ChatMessage>(entity =>
        {
            entity.HasIndex(m => new { m.ReceiverId, m.CreatedAt });
            entity.HasIndex(m => new { m.GroupId, m.CreatedAt });
            entity.HasIndex(m => m.MessageType);

            entity.HasOne(m => m.Sender)
                  .WithMany(u => u.SentMessages)
                  .HasForeignKey(m => m.SenderId)
                  .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(m => m.Receiver)
                  .WithMany(u => u.ReceivedMessages)
                  .HasForeignKey(m => m.ReceiverId)
                  .IsRequired(false)
                  .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(m => m.Group)
                  .WithMany(g => g.Messages)
                  .HasForeignKey(m => m.GroupId)
                  .IsRequired(false)
                  .OnDelete(DeleteBehavior.Restrict);

            entity.HasCheckConstraint("CK_Message_Target",
                "(GroupId IS NOT NULL AND ReceiverId IS NULL) OR " +
                "(GroupId IS NULL AND ReceiverId IS NOT NULL)");
        });

        // ── FileAttachment ───────────────────────────────────────────────────
        // Explicit nav props prevent shadow FK 'MessageId1' and 'UploaderId'.
        modelBuilder.Entity<FileAttachment>(entity =>
        {
            entity.HasIndex(f => f.MessageId);
            entity.HasIndex(f => f.UploadStatus);
            entity.HasIndex(f => f.ProcessingStatus);
            entity.HasIndex(f => f.StorageKey);
            entity.HasIndex(f => f.CreatedAt);

            entity.HasOne(f => f.Message)
                  .WithMany(m => m.Attachments)
                  .HasForeignKey(f => f.MessageId)
                  .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(f => f.Uploader)
                  .WithMany(u => u.UploadedFiles)
                  .HasForeignKey(f => f.UploadedBy)
                  .OnDelete(DeleteBehavior.Restrict);
        });

        // ── UploadSession ────────────────────────────────────────────────────
        modelBuilder.Entity<UploadSession>(entity =>
        {
            entity.HasIndex(s => s.FileAttachmentId);
            entity.HasIndex(s => s.UserId);
            entity.HasIndex(s => new { s.SessionStatus, s.PresignedUrlExpiresAt });

            entity.HasOne(s => s.FileAttachment)
                  .WithMany(a => a.UploadSessions)
                  .HasForeignKey(s => s.FileAttachmentId)
                  .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(s => s.User)
                  .WithMany()
                  .HasForeignKey(s => s.UserId)
                  .OnDelete(DeleteBehavior.Restrict);
        });
    }
}
