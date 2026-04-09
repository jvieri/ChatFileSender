using ChatWithFiles.Domain.Entities;
using ChatWithFiles.Domain.Interfaces;
using ChatWithFiles.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace ChatWithFiles.Infrastructure.Repositories;

public class EfRepository<T> : IRepository<T> where T : class
{
    protected readonly ChatDbContext _context;
    
    public EfRepository(ChatDbContext context)
    {
        _context = context;
    }
    
    public virtual async Task<T?> GetByIdAsync(Guid id, CancellationToken ct = default)
    {
        return await _context.Set<T>().FindAsync(new object[] { id }, cancellationToken: ct);
    }
    
    public virtual async Task<T> CreateAsync(T entity, CancellationToken ct = default)
    {
        await _context.Set<T>().AddAsync(entity, ct);
        return entity;
    }
    
    public virtual Task UpdateAsync(T entity, CancellationToken ct = default)
    {
        _context.Entry(entity).State = EntityState.Modified;
        return Task.CompletedTask;
    }
    
    public virtual async Task DeleteAsync(T entity, CancellationToken ct = default)
    {
        await Task.FromResult(_context.Set<T>().Remove(entity));
    }
}

public interface IRepository<T> where T : class
{
    Task<T?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<T> CreateAsync(T entity, CancellationToken ct = default);
    Task UpdateAsync(T entity, CancellationToken ct = default);
    Task DeleteAsync(T entity, CancellationToken ct = default);
}
