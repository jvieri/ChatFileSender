using ChatWithFiles.Domain.Entities;
using ChatWithFiles.Domain.Interfaces;
using ChatWithFiles.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace ChatWithFiles.Infrastructure.Repositories;

public class EfUserRepository : EfRepository<User>, IUserRepository
{
    public EfUserRepository(ChatDbContext context) : base(context)
    {
    }
    
    public async Task<User?> GetByUsernameAsync(string username, CancellationToken ct = default)
    {
        return await _context.Users
            .FirstOrDefaultAsync(u => u.Username == username, ct);
    }
    
    public async Task<List<User>> GetActiveUsersAsync(CancellationToken ct = default)
    {
        return await _context.Users
            .Where(u => u.IsActive)
            .OrderBy(u => u.Username)
            .ToListAsync(ct);
    }
}
