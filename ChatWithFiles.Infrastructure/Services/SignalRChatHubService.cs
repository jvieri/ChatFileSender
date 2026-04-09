using Microsoft.AspNetCore.SignalR;
using ChatWithFiles.Domain.Interfaces;
using ChatWithFiles.Infrastructure.Hubs;

namespace ChatWithFiles.Infrastructure.Services;

public class SignalRChatHubService : IChatHubService
{
    private readonly IHubContext<ChatHub> _hubContext;
    
    public SignalRChatHubService(IHubContext<ChatHub> hubContext)
    {
        _hubContext = hubContext;
    }
    
    public async Task NotifyNewMessageAsync(string chatId, object message)
    {
        await _hubContext.Clients.Group(chatId).SendAsync("ReceiveMessage", message);
    }
    
    public async Task NotifyFileUploadProgressAsync(string userId, Guid fileId, int progress, string status)
    {
        await _hubContext.Clients.User(userId).SendAsync("FileUploadProgress", new
        {
            fileId,
            progress,
            status
        });
    }
    
    public async Task NotifyFileProcessingCompletedAsync(string chatId, Guid fileId, object metadata)
    {
        await _hubContext.Clients.Group(chatId).SendAsync("FileProcessingCompleted", new
        {
            fileId,
            metadata
        });
    }
    
    public async Task NotifyFileProcessingFailedAsync(string chatId, Guid fileId, string error, string? errorCode)
    {
        await _hubContext.Clients.Group(chatId).SendAsync("FileError", new
        {
            fileId,
            errorMessage = error,
            errorCode
        });
    }
    
    public async Task NotifyMessageStatusAsync(string userId, Guid messageId, string status)
    {
        await _hubContext.Clients.User(userId).SendAsync("MessageStatusUpdate", new
        {
            messageId,
            status
        });
    }
    
    public async Task NotifyTypingIndicatorAsync(string chatId, Guid userId, string userName, bool isTyping)
    {
        await _hubContext.Clients.Group(chatId).SendAsync("TypingIndicator", new
        {
            userId,
            userName,
            isTyping
        });
    }
}
