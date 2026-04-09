using ChatWithFiles.Contracts.Files;
using ChatWithFiles.Contracts.Messages;
using ChatWithFiles.Domain.Entities;
using ChatWithFiles.Domain.Enums;
using ChatWithFiles.Domain.Interfaces;
using MediatR;

namespace ChatWithFiles.Application.Commands.Messages;

public class SendMessageCommandHandler : IRequestHandler<SendMessageCommand, ChatMessageDto>
{
    private readonly IChatMessageRepository _messageRepository;
    private readonly IChatHubService _chatHub;
    private readonly IUnitOfWork _unitOfWork;
    
    public SendMessageCommandHandler(
        IChatMessageRepository messageRepository,
        IChatHubService chatHub,
        IUnitOfWork unitOfWork)
    {
        _messageRepository = messageRepository;
        _chatHub = chatHub;
        _unitOfWork = unitOfWork;
    }
    
    public async Task<ChatMessageDto> Handle(SendMessageCommand request, CancellationToken cancellationToken)
    {
        // Create the message
        var message = new ChatMessage
        {
            Id = Guid.NewGuid(),
            SenderId = request.SenderId,
            ReceiverId = request.ReceiverId,
            GroupId = request.GroupId,
            TextContent = request.TextContent,
            MessageType = MessageType.Text,
            Status = MessageStatus.Sent,
            CreatedAt = DateTime.UtcNow
        };
        
        await _messageRepository.CreateAsync(message, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        await _unitOfWork.CommitTransactionAsync(cancellationToken);
        
        // Determine chat ID for SignalR notification
        var chatId = GetChatId(message);
        
        // Notify via SignalR
        await _chatHub.NotifyNewMessageAsync(chatId, new
        {
            messageId = message.Id,
            senderId = message.SenderId,
            senderName = "User", // Would come from user service
            receiverId = message.ReceiverId,
            groupId = message.GroupId,
            textContent = message.TextContent,
            messageType = message.MessageType.ToString(),
            files = new List<object>(),
            createdAt = message.CreatedAt
        });
        
        // Convert to DTO
        return new ChatMessageDto(
            message.Id,
            message.SenderId,
            message.ReceiverId,
            message.GroupId,
            message.TextContent,
            message.MessageType.ToString(),
            message.Status.ToString(),
            new List<ChatWithFiles.Contracts.Files.FileAttachmentDto>(),
            message.CreatedAt
        );
    }
    
    private string GetChatId(ChatMessage message)
    {
        if (message.GroupId.HasValue)
        {
            return $"group_{message.GroupId.Value:N}";
        }
        
        // For direct messages, use both user IDs so either can receive
        return $"direct_{message.SenderId:N}_{message.ReceiverId:N}";
    }
}
