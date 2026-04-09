using ChatWithFiles.Domain.Interfaces;
using ChatWithFiles.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore.Storage;

namespace ChatWithFiles.Infrastructure.Repositories;

public class EfUnitOfWork : IUnitOfWork, IDisposable
{
    private readonly ChatDbContext _context;
    private IDbContextTransaction? _currentTransaction;
    private bool _disposed;
    
    public EfUnitOfWork(ChatDbContext context)
    {
        _context = context;
    }
    
    public async Task<int> SaveChangesAsync(CancellationToken ct = default)
    {
        return await _context.SaveChangesAsync(ct);
    }
    
    public async Task BeginTransactionAsync(CancellationToken ct = default)
    {
        if (_currentTransaction != null)
        {
            return;
        }
        
        _currentTransaction = await _context.Database.BeginTransactionAsync(ct);
    }
    
    public async Task CommitTransactionAsync(CancellationToken ct = default)
    {
        try
        {
            await _context.SaveChangesAsync(ct);
            
            if (_currentTransaction != null)
            {
                await _currentTransaction.CommitAsync(ct);
            }
        }
        catch
        {
            await RollbackTransactionAsync(ct);
            throw;
        }
        finally
        {
            if (_currentTransaction != null)
            {
                _currentTransaction.Dispose();
                _currentTransaction = null;
            }
        }
    }
    
    public async Task RollbackTransactionAsync(CancellationToken ct = default)
    {
        try
        {
            if (_currentTransaction != null)
            {
                await _currentTransaction.RollbackAsync(ct);
            }
        }
        finally
        {
            if (_currentTransaction != null)
            {
                _currentTransaction.Dispose();
                _currentTransaction = null;
            }
        }
    }
    
    public void Dispose()
    {
        if (_disposed) return;
        
        _currentTransaction?.Dispose();
        _context.Dispose();
        _disposed = true;
    }
}
