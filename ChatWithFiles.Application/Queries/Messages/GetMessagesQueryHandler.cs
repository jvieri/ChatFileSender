using ChatWithFiles.Contracts.Files;
using ChatWithFiles.Contracts.Messages;
using ChatWithFiles.Domain.Interfaces;
using MediatR;

namespace ChatWithFiles.Application.Queries.Messages;

public class GetMessagesQueryHandler : IRequestHandler<GetMessagesQuery, GetMessagesResponse>
{
    private readonly IChatMessageRepository _messageRepository;
    
    public GetMessagesQueryHandler(IChatMessageRepository messageRepository)
    {
        _messageRepository = messageRepository;
    }
    
    public async Task<GetMessagesResponse> Handle(GetMessagesQuery request, CancellationToken cancellationToken)
    {
        List<ChatWithFiles.Domain.Entities.ChatMessage> messages;
        
        if (request.GroupId.HasValue)
        {
            messages = await _messageRepository.GetGroupMessagesAsync(
                request.GroupId.Value,
                request.Page,
                request.PageSize,
                cancellationToken
            );
        }
        else if (request.UserId.HasValue)
        {
            // For direct messages, we need to get messages between current user and target user
            // This is simplified - in reality you'd pass both user IDs
            messages = await _messageRepository.GetRecentMessagesAsync(
                request.UserId,
                null,
                request.PageSize,
                cancellationToken
            );
        }
        else
        {
            messages = new List<ChatWithFiles.Domain.Entities.ChatMessage>();
        }
        
        var messageDtos = messages.Select(m => new ChatMessageDto(
            m.Id,
            m.SenderId,
            m.ReceiverId,
            m.GroupId,
            m.TextContent,
            m.MessageType.ToString(),
            m.Status.ToString(),
            m.Attachments.Select(a => new FileAttachmentDto(
                a.Id,
                a.FileName,
                a.OriginalFileName,
                a.FileType,
                a.FileExtension,
                a.FileSize,
                a.UploadStatus.ToString(),
                a.UploadProgress,
                a.ThumbnailUrl,
                a.IsScanned,
                a.ScanStatus?.ToString(),
                a.Width,
                a.Height,
                a.Duration,
                a.ErrorMessage,
                a.CreatedAt
            )).ToList(),
            m.CreatedAt
        )).ToList();
        
        return new GetMessagesResponse(
            messageDtos,
            messageDtos.Count,
            request.Page,
            request.PageSize
        );
    }
}
