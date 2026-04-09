using Microsoft.EntityFrameworkCore;
using MediatR;
using System.Reflection;
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

// Add services to the container
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Add SignalR
builder.Services.AddSignalR(options =>
{
    options.EnableDetailedErrors = true;
    options.MaximumReceiveMessageSize = 64 * 1024; // 64 KB
})
.AddMessagePackProtocol()
.AddJsonProtocol(options =>
{
    options.PayloadSerializerOptions.PropertyNameCaseInsensitive = true;
});

// Add CORS
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyHeader()
              .AllowAnyMethod()
              .AllowAnyOrigin();
    });
    
    // For production, use specific origins
    options.AddPolicy("Production", policy =>
    {
        policy.WithOrigins("https://yourdomain.com")
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials();
    });
});

// Add Database
builder.Services.AddDbContext<ChatDbContext>(options =>
    options.UseSqlServer(
        builder.Configuration.GetConnectionString("DefaultConnection"),
        sql => sql.EnableRetryOnFailure(
            maxRetryCount: 3,
            maxRetryDelay: TimeSpan.FromSeconds(10),
            errorNumbersToAdd: null)
    )
);

// Add Redis for SignalR backplane (optional, for scale-out)
// builder.Services.AddSignalR().AddStackExchangeRedis("your-redis-connection");

// Add Repositories
builder.Services.AddScoped<IChatMessageRepository, EfChatMessageRepository>();
builder.Services.AddScoped<IFileAttachmentRepository, EfFileAttachmentRepository>();
builder.Services.AddScoped<IUploadSessionRepository, EfUploadSessionRepository>();
builder.Services.AddScoped<IUserRepository, EfUserRepository>();
builder.Services.AddScoped<IChatGroupRepository, EfChatGroupRepository>();
builder.Services.AddScoped<IUnitOfWork, EfUnitOfWork>();

// Add Services
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

// Add MediatR
builder.Services.AddMediatR(cfg => 
{
    cfg.RegisterServicesFromAssembly(Assembly.GetExecutingAssembly());
    cfg.RegisterServicesFromAssembly(typeof(CreateMessageWithFileCommandHandler).Assembly);
});

// Add Background Services
builder.Services.AddHostedService<FileProcessingConsumer>();
// builder.Services.AddHostedService<ExpiredSessionCleanupService>();
// builder.Services.AddHostedService<FailedUploadRetryService>();

// Add Authentication & Authorization (configure with your auth provider)
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = builder.Configuration["Auth:Authority"];
        options.Audience = builder.Configuration["Auth:Audience"];
        
        // For SignalR authentication
        options.Events = new Microsoft.AspNetCore.Authentication.JwtBearer.JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                var accessToken = context.Request.Query["access_token"];
                var path = context.HttpContext.Request.Path;
                if (!string.IsNullOrEmpty(accessToken) && path.StartsWithSegments("/hubs"))
                {
                    context.Token = accessToken;
                }
                return Task.CompletedTask;
            }
        };
    });

builder.Services.AddAuthorization();

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseCors("AllowAll"); // Use "Production" in production
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

// Map SignalR Hubs
app.MapHub<ChatHub>("/hubs/chat");

// Health check endpoint
app.MapGet("/health", () => Results.Ok(new { Status = "Healthy", Timestamp = DateTime.UtcNow }));

app.Run();
