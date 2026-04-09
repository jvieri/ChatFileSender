using Microsoft.AspNetCore.Mvc;
using ChatWithFiles.Domain.Entities;
using ChatWithFiles.Domain.Interfaces;

namespace ChatWithFiles.Api.Controllers;

[ApiController]
[Route("api/v1/[controller]")]
[Produces("application/json")]
public class SimulationController : ControllerBase
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<SimulationController> _logger;
    private static readonly List<User> _demoUsers = new();
    private static readonly List<ChatGroup> _demoGroups = new();
    
    public SimulationController(
        IUnitOfWork unitOfWork,
        ILogger<SimulationController> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }
    
    /// <summary>
    /// Initialize demo data for testing
    /// </summary>
    [HttpPost("initialize")]
    public async Task<IActionResult> InitializeDemoData()
    {
        if (_demoUsers.Count > 0)
        {
            return Ok(new
            {
                message = "Demo data already exists",
                users = _demoUsers.Select(u => new { u.Id, u.Username, u.DisplayName }),
                groups = _demoGroups.Select(g => new { g.Id, g.Name })
            });
        }
        
        // Create demo users
        var user1 = new User
        {
            Id = Guid.Parse("11111111-1111-1111-1111-111111111111"),
            Username = "user1",
            Email = "user1@demo.com",
            DisplayName = "Alice",
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };
        
        var user2 = new User
        {
            Id = Guid.Parse("22222222-2222-2222-2222-222222222222"),
            Username = "user2",
            Email = "user2@demo.com",
            DisplayName = "Bob",
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };
        
        var user3 = new User
        {
            Id = Guid.Parse("33333333-3333-3333-3333-333333333333"),
            Username = "user3",
            Email = "user3@demo.com",
            DisplayName = "Charlie",
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };
        
        _demoUsers.AddRange(user1, user2, user3);
        
        // Create demo group
        var group = new ChatGroup
        {
            Id = Guid.Parse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"),
            Name = "Development Team",
            Description = "Team chat for developers",
            CreatedBy = user1.Id,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };
        
        _demoGroups.Add(group);
        
        _logger.LogInformation("Demo data initialized: 3 users, 1 group");
        
        return Ok(new
        {
            message = "Demo data created successfully",
            users = _demoUsers.Select(u => new { u.Id, u.Username, u.DisplayName, u.Email }),
            groups = _demoGroups.Select(g => new { g.Id, g.Name, g.Description })
        });
    }
    
    /// <summary>
    /// Get demo users for testing
    /// </summary>
    [HttpGet("users")]
    public IActionResult GetDemoUsers()
    {
        if (_demoUsers.Count == 0)
        {
            return Ok(new { message = "No demo users. Call /initialize first." });
        }
        
        return Ok(new
        {
            users = _demoUsers.Select(u => new
            {
                u.Id,
                u.Username,
                u.DisplayName,
                u.Email
            })
        });
    }
    
    /// <summary>
    /// Get demo groups for testing
    /// </summary>
    [HttpGet("groups")]
    public IActionResult GetDemoGroups()
    {
        if (_demoGroups.Count == 0)
        {
            return Ok(new { message = "No demo groups. Call /initialize first." });
        }
        
        return Ok(new
        {
            groups = _demoGroups.Select(g => new
            {
                g.Id,
                g.Name,
                g.Description
            })
        });
    }
}
