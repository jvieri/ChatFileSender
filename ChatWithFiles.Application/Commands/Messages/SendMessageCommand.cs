using ChatWithFiles.Contracts.Messages;
using MediatR;

namespace ChatWithFiles.Application.Commands.Messages;

public record SendMessageCommand(
    Guid SenderId,
    string SenderName,
    Guid? ReceiverId,
    Guid? GroupId,
    string TextContent
) : IRequest<ChatMessageDto>;
