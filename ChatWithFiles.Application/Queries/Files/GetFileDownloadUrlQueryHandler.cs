using ChatWithFiles.Contracts.Files;
using ChatWithFiles.Domain.Interfaces;
using MediatR;

namespace ChatWithFiles.Application.Queries.Files;

public class GetFileDownloadUrlQueryHandler : IRequestHandler<GetFileDownloadUrlQuery, FileDownloadUrlResponse>
{
    private readonly IFileAttachmentRepository _fileRepository;
    private readonly IStorageService _storageService;
    private const int DownloadUrlExpirationHours = 24;
    
    public GetFileDownloadUrlQueryHandler(
        IFileAttachmentRepository fileRepository,
        IStorageService storageService)
    {
        _fileRepository = fileRepository;
        _storageService = storageService;
    }
    
    public async Task<FileDownloadUrlResponse> Handle(GetFileDownloadUrlQuery request, CancellationToken cancellationToken)
    {
        var file = await _fileRepository.GetByIdAsync(request.FileId, cancellationToken);
        
        if (file == null)
        {
            throw new KeyNotFoundException($"File {request.FileId} not found");
        }
        
        if (file.UploadStatus != ChatWithFiles.Domain.Enums.UploadStatus.Completed)
        {
            throw new InvalidOperationException("File is not ready for download");
        }
        
        var downloadUrl = await _storageService.GenerateDownloadUrlAsync(
            file.StorageKey,
            TimeSpan.FromHours(DownloadUrlExpirationHours),
            cancellationToken
        );
        
        return new FileDownloadUrlResponse(
            downloadUrl,
            DateTime.UtcNow.AddHours(DownloadUrlExpirationHours),
            file.OriginalFileName,
            file.FileSize
        );
    }
}
