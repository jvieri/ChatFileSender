using ChatWithFiles.Domain.Entities;
using ChatWithFiles.Domain.Interfaces;
using ChatWithFiles.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace ChatWithFiles.Infrastructure.Repositories;

public class EfChatGroupRepository : EfRepository<ChatGroup>, IChatGroupRepository
{
    public EfChatGroupRepository(ChatDbContext context) : base(context)
    {
    }
    
    public async Task<List<ChatGroup>> GetUserGroupsAsync(Guid userId, CancellationToken ct = default)
    {
        return await _context.ChatGroups
            .Include(g => g.Members)
            .Where(g => g.Members.Any(m => m.UserId == userId && m.LeftAt == null) && g.IsActive)
            .OrderByDescending(g => g.CreatedAt)
            .ToListAsync(ct);
    }
    
    public async Task<bool> IsMemberAsync(Guid groupId, Guid userId, CancellationToken ct = default)
    {
        return await _context.ChatGroupMembers
            .AnyAsync(m => m.GroupId == groupId && m.UserId == userId && m.LeftAt == null, ct);
    }
    
    public async Task<List<Guid>> GetGroupMemberIdsAsync(Guid groupId, CancellationToken ct = default)
    {
        return await _context.ChatGroupMembers
            .Where(m => m.GroupId == groupId && m.LeftAt == null)
            .Select(m => m.UserId)
            .ToListAsync(ct);
    }
}
