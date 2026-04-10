using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging;
using ChatWithFiles.Domain.Interfaces;

namespace ChatWithFiles.Infrastructure.Hubs;

public class ChatHub : Hub
{
    private readonly ILogger<ChatHub> _logger;
    
    public ChatHub(ILogger<ChatHub> logger)
    {
        _logger = logger;
    }
    
    public async Task JoinChat(string chatId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, chatId);
        _logger.LogInformation("User {ConnectionId} joined chat {ChatId}", Context.ConnectionId, chatId);
    }
    
    public async Task LeaveChat(string chatId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, chatId);
        _logger.LogInformation("User {ConnectionId} left chat {ChatId}", Context.ConnectionId, chatId);
    }
    
    public async Task ReportUploadProgress(Guid fileId, int progress, string status)
    {
        // This can be used for client-side progress tracking
        // The server will also track this via the API
        _logger.LogInformation("File {FileId} upload progress: {Progress}% - {Status}", 
            fileId, progress, status);
    }
    
    public async Task SendTypingIndicator(string chatId, bool isTyping)
    {
        var userId = Context.UserIdentifier;
        var userName = Context.User?.Identity?.Name ?? "Unknown";
        
        await Clients.Group(chatId).SendAsync("TypingIndicator", new
        {
            userId,
            userName,
            isTyping
        });
    }
    
    public override async Task OnConnectedAsync()
    {
        var userId = Context.User?.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value
                     ?? "(anonymous)";
        _logger.LogInformation(
            "SignalR CONNECTED — ConnectionId: {ConnectionId} | UserId: {UserId}",
            Context.ConnectionId, userId);
        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        _logger.LogInformation(
            "SignalR DISCONNECTED — ConnectionId: {ConnectionId} | Error: {Error}",
            Context.ConnectionId, exception?.Message ?? "clean");
        await base.OnDisconnectedAsync(exception);
    }
}
