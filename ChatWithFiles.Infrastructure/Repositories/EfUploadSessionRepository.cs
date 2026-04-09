using ChatWithFiles.Domain.Entities;
using ChatWithFiles.Domain.Enums;
using ChatWithFiles.Domain.Interfaces;
using ChatWithFiles.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace ChatWithFiles.Infrastructure.Repositories;

public class EfUploadSessionRepository : EfRepository<UploadSession>, IUploadSessionRepository
{
    public EfUploadSessionRepository(ChatDbContext context) : base(context)
    {
    }
    
    public async Task<List<UploadSession>> GetExpiredSessionsAsync(CancellationToken ct = default)
    {
        return await _context.UploadSessions
            .Where(s => s.PresignedUrlExpiresAt < DateTime.UtcNow && 
                        s.SessionStatus == SessionStatus.Active)
            .ToListAsync(ct);
    }
}
