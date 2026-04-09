using ChatWithFiles.Contracts.Messages;
using MediatR;

namespace ChatWithFiles.Application.Queries.Messages;

public record GetMessagesQuery(
    Guid? UserId,
    Guid? GroupId,
    int Page,
    int PageSize
) : IRequest<GetMessagesResponse>;
