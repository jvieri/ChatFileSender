using ChatWithFiles.Domain.Entities;
using ChatWithFiles.Domain.Enums;
using ChatWithFiles.Domain.Interfaces;
using ChatWithFiles.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace ChatWithFiles.Infrastructure.Repositories;

public class EfChatMessageRepository : EfRepository<ChatMessage>, IChatMessageRepository
{
    public EfChatMessageRepository(ChatDbContext context) : base(context)
    {
    }
    
    public async Task<List<ChatMessage>> GetDirectMessagesAsync(Guid userId1, Guid userId2, int page, int pageSize, CancellationToken ct = default)
    {
        return await _context.ChatMessages
            .Include(m => m.Attachments)
            .Include(m => m.Sender)
            .Where(m => m.ReceiverId == userId1 && m.SenderId == userId2 || 
                        m.ReceiverId == userId2 && m.SenderId == userId1)
            .OrderByDescending(m => m.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(ct);
    }
    
    public async Task<List<ChatMessage>> GetGroupMessagesAsync(Guid groupId, int page, int pageSize, CancellationToken ct = default)
    {
        return await _context.ChatMessages
            .Include(m => m.Attachments)
            .Include(m => m.Sender)
            .Where(m => m.GroupId == groupId)
            .OrderByDescending(m => m.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(ct);
    }
    
    public async Task<List<ChatMessage>> GetRecentMessagesAsync(Guid? userId, Guid? groupId, int count, CancellationToken ct = default)
    {
        var query = _context.ChatMessages
            .Include(m => m.Attachments)
            .Include(m => m.Sender)
            .AsQueryable();
        
        if (groupId.HasValue)
        {
            query = query.Where(m => m.GroupId == groupId.Value);
        }
        else if (userId.HasValue)
        {
            query = query.Where(m => m.ReceiverId == userId.Value || m.SenderId == userId.Value);
        }
        
        return await query
            .OrderByDescending(m => m.CreatedAt)
            .Take(count)
            .ToListAsync(ct);
    }
}
