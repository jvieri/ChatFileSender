using ChatWithFiles.Contracts.Files;
using MediatR;

namespace ChatWithFiles.Application.Commands.Files;

public record ConfirmFileUploadCommand(
    Guid FileId,
    Guid UserId,
    string? Checksum = null
) : IRequest<ConfirmFileUploadResponse>;
