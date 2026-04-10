using Microsoft.EntityFrameworkCore;
using MediatR;
using System.Reflection;
using System.Security.Claims;
using ChatWithFiles.Domain.Entities;
using ChatWithFiles.Domain.Interfaces;
using ChatWithFiles.Infrastructure.Persistence;
using ChatWithFiles.Infrastructure.Repositories;
using ChatWithFiles.Infrastructure.Services;
using ChatWithFiles.Infrastructure.Hubs;
using ChatWithFiles.Infrastructure.Consumers;
using ChatWithFiles.Api.Middleware;
using ChatWithFiles.Application.Commands.Messages;
using Microsoft.AspNetCore.Authentication.JwtBearer;

var builder = WebApplication.CreateBuilder(args);

// Allow large file uploads (100 MB) for the direct upload endpoint.
builder.WebHost.ConfigureKestrel(k => k.Limits.MaxRequestBodySize = 110_000_000);

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddSignalR(options =>
{
    options.EnableDetailedErrors = true;
    options.MaximumReceiveMessageSize = 64 * 1024;
})
.AddMessagePackProtocol()
.AddJsonProtocol(options =>
{
    options.PayloadSerializerOptions.PropertyNameCaseInsensitive = true;
});

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
        policy.AllowAnyHeader().AllowAnyMethod().AllowAnyOrigin());
});

builder.Services.AddDbContext<ChatDbContext>(options =>
    options.UseSqlServer(
        builder.Configuration.GetConnectionString("DefaultConnection"),
        sql => sql.EnableRetryOnFailure(maxRetryCount: 3,
            maxRetryDelay: TimeSpan.FromSeconds(10),
            errorNumbersToAdd: null)
    )
);

builder.Services.AddScoped<IChatMessageRepository, EfChatMessageRepository>();
builder.Services.AddScoped<IFileAttachmentRepository, EfFileAttachmentRepository>();
builder.Services.AddScoped<IUploadSessionRepository, EfUploadSessionRepository>();
builder.Services.AddScoped<IUserRepository, EfUserRepository>();
builder.Services.AddScoped<IChatGroupRepository, EfChatGroupRepository>();
builder.Services.AddScoped<IUnitOfWork, EfUnitOfWork>();

builder.Services.AddSingleton<IStorageService>(sp =>
{
    var connectionString = builder.Configuration["AzureBlob:ConnectionString"];
    var containerName = builder.Configuration["AzureBlob:ContainerName"] ?? "chat-files";
    return new AzureBlobStorageService(connectionString!, containerName);
});

builder.Services.AddSingleton<IMessageBus>(sp =>
{
    var connectionString = builder.Configuration["RabbitMQ:ConnectionString"];
    return new RabbitMqMessageBus(connectionString!);
});

builder.Services.AddScoped<IChatHubService, SignalRChatHubService>();
builder.Services.AddSingleton<IHttpContextAccessor, HttpContextAccessor>();
builder.Services.AddScoped<ICurrentUserAccessor, CurrentUserAccessor>();

builder.Services.AddMediatR(cfg =>
{
    cfg.RegisterServicesFromAssembly(Assembly.GetExecutingAssembly());
    cfg.RegisterServicesFromAssembly(typeof(CreateMessageWithFileCommandHandler).Assembly);
});

builder.Services.AddHostedService<FileProcessingConsumer>();

builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = builder.Configuration["Auth:Authority"];
        options.Audience = builder.Configuration["Auth:Audience"];
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                var accessToken = context.Request.Query["access_token"];
                if (!string.IsNullOrEmpty(accessToken) &&
                    context.HttpContext.Request.Path.StartsWithSegments("/hubs"))
                {
                    context.Token = accessToken;
                }
                return Task.CompletedTask;
            }
        };
    });

builder.Services.AddAuthorization();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}
else
{
    app.UseHttpsRedirection();
}

app.UseCors("AllowAll");
app.UseAuthentication();
app.UseAuthorization();

// Demo auth middleware: runs AFTER UseAuthentication so it always wins.
// Reads X-User-Id header (REST/Dio calls) or ?userId= query param (SignalR WebSocket).
app.Use(async (context, next) =>
{
    var userId = context.Request.Headers["X-User-Id"].FirstOrDefault();
    if (string.IsNullOrEmpty(userId))
        userId = context.Request.Query["userId"].ToString();

    if (!string.IsNullOrEmpty(userId))
    {
        var demoUsers = new Dictionary<string, (string name, string email)>
        {
            ["11111111-1111-1111-1111-111111111111"] = ("Alice",   "alice@demo.com"),
            ["22222222-2222-2222-2222-222222222222"] = ("Bob",     "bob@demo.com"),
            ["33333333-3333-3333-3333-333333333333"] = ("Charlie", "charlie@demo.com"),
        };
        var (name, email) = demoUsers.GetValueOrDefault(userId, ("Unknown", "unknown@demo.com"));
        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, userId),
            new Claim(ClaimTypes.Name, name),
            new Claim(ClaimTypes.Email, email),
        };
        context.User = new ClaimsPrincipal(new ClaimsIdentity(claims, "Demo"));
    }
    await next();
});

app.MapControllers();
app.MapHub<ChatHub>("/hubs/chat");
app.MapGet("/health", () => Results.Ok(new { Status = "Healthy", Timestamp = DateTime.UtcNow }));

// Development: recreate schema and seed demo data on every startup.
if (app.Environment.IsDevelopment())
{
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<ChatDbContext>();

    db.Database.EnsureDeleted();
    db.Database.EnsureCreated();

    var aliceId   = Guid.Parse("11111111-1111-1111-1111-111111111111");
    var bobId     = Guid.Parse("22222222-2222-2222-2222-222222222222");
    var charlieId = Guid.Parse("33333333-3333-3333-3333-333333333333");
    var groupId   = Guid.Parse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");

    db.Users.AddRange(
        new User { Id = aliceId,   Username = "alice",   Email = "alice@demo.com",   DisplayName = "Alice",   IsActive = true, CreatedAt = DateTime.UtcNow },
        new User { Id = bobId,     Username = "bob",     Email = "bob@demo.com",     DisplayName = "Bob",     IsActive = true, CreatedAt = DateTime.UtcNow },
        new User { Id = charlieId, Username = "charlie", Email = "charlie@demo.com", DisplayName = "Charlie", IsActive = true, CreatedAt = DateTime.UtcNow }
    );
    db.ChatGroups.Add(new ChatGroup
    {
        Id = groupId,
        Name = "Development Team",
        Description = "Team chat for developers",
        CreatedBy = aliceId,
        IsActive = true,
        CreatedAt = DateTime.UtcNow
    });
    db.SaveChanges();

    app.Logger.LogInformation("Demo DB recreated and seeded (Alice, Bob, Charlie + group).");
}

app.Run();
