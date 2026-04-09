using ChatWithFiles.Contracts.Files;
using MediatR;

namespace ChatWithFiles.Application.Queries.Files;

public record GetFileDownloadUrlQuery(Guid FileId, Guid UserId) : IRequest<FileDownloadUrlResponse>;
