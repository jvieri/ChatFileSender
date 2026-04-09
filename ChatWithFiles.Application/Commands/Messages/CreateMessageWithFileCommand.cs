using ChatWithFiles.Contracts.Files;
using MediatR;

namespace ChatWithFiles.Application.Commands.Messages;

public record CreateMessageWithFileCommand(
    Guid SenderId,
    Guid? ReceiverId,
    Guid? GroupId,
    string? TextContent,
    List<CreateFileAttachmentRequest> Files
) : IRequest<CreateMessageWithFileResponse>;
