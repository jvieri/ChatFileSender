using ChatWithFiles.Contracts.Files;
using ChatWithFiles.Domain.Entities;
using ChatWithFiles.Domain.Enums;
using ChatWithFiles.Domain.Interfaces;
using MediatR;

namespace ChatWithFiles.Application.Commands.Messages;

public class CreateMessageWithFileCommandHandler : IRequestHandler<CreateMessageWithFileCommand, CreateMessageWithFileResponse>
{
    private readonly IChatMessageRepository _messageRepository;
    private readonly IFileAttachmentRepository _fileRepository;
    private readonly IStorageService _storageService;
    private readonly IUnitOfWork _unitOfWork;
    private const long MaxFileSize = 100 * 1024 * 1024; // 100 MB
    private const int UrlExpirationHours = 1;
    
    public CreateMessageWithFileCommandHandler(
        IChatMessageRepository messageRepository,
        IFileAttachmentRepository fileRepository,
        IStorageService storageService,
        IUnitOfWork unitOfWork)
    {
        _messageRepository = messageRepository;
        _fileRepository = fileRepository;
        _storageService = storageService;
        _unitOfWork = unitOfWork;
    }
    
    public async Task<CreateMessageWithFileResponse> Handle(CreateMessageWithFileCommand request, CancellationToken cancellationToken)
    {
        // 1. Create the chat message
        var message = new ChatMessage
        {
            Id = Guid.NewGuid(),
            SenderId = request.SenderId,
            ReceiverId = request.ReceiverId,
            GroupId = request.GroupId,
            TextContent = request.TextContent,
            MessageType = request.Files.Any() ? MessageType.File : MessageType.Text,
            Status = MessageStatus.Sent,
            CreatedAt = DateTime.UtcNow
        };

        await _messageRepository.CreateAsync(message, cancellationToken);

        // 2. Create file attachments and generate upload URLs
        var uploadUrls = new List<FileUploadUrlResponse>();

        foreach (var fileRequest in request.Files)
        {
            if (fileRequest.FileSize > MaxFileSize)
                throw new ArgumentException($"File size {fileRequest.FileSize} exceeds maximum allowed size of {MaxFileSize} bytes");

            if (!IsValidFileType(fileRequest.FileType))
                throw new ArgumentException($"File type '{fileRequest.FileType}' is not allowed");

            var extension = Path.GetExtension(fileRequest.FileName);
            var storageKey = GenerateStorageKey(message.Id, fileRequest.FileName);

            var fileAttachment = new FileAttachment
            {
                Id = Guid.NewGuid(),
                MessageId = message.Id,
                FileName = fileRequest.FileName,
                OriginalFileName = fileRequest.FileName,
                FileType = fileRequest.FileType,
                FileExtension = extension,
                FileSize = fileRequest.FileSize,
                StorageKey = storageKey,
                UploadStatus = UploadStatus.Pending,
                UploadProgress = 0,
                UploadedBy = request.SenderId,
                CreatedAt = DateTime.UtcNow
            };

            await _fileRepository.CreateAsync(fileAttachment, cancellationToken);

            // SAS URL is computed locally (no network call to Azurite needed).
            // Flutter uses /files/{id}/upload-bytes directly, so this URL is informational.
            string uploadUrl;
            try
            {
                uploadUrl = await _storageService.GenerateUploadUrlAsync(
                    storageKey,
                    TimeSpan.FromHours(UrlExpirationHours),
                    MaxFileSize,
                    cancellationToken
                );
            }
            catch
            {
                uploadUrl = string.Empty;
            }

            uploadUrls.Add(new FileUploadUrlResponse(
                fileAttachment.Id,
                uploadUrl,
                DateTime.UtcNow.AddHours(UrlExpirationHours)
            ));
        }

        // 3. Persist message + all attachments atomically via EF implicit transaction
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return new CreateMessageWithFileResponse(message.Id, uploadUrls);
    }
    
    private bool IsValidFileType(string mimeType)
    {
        var allowedTypes = new HashSet<string>
        {
            // Images
            "image/jpeg", "image/png", "image/gif", "image/webp", "image/bmp",
            // Documents
            "application/pdf",
            "application/msword",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "application/vnd.ms-excel",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "application/vnd.ms-powerpoint",
            "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            // Videos
            "video/mp4", "video/webm", "video/quicktime", "video/x-msvideo",
            // Audio
            "audio/mpeg", "audio/mp4", "audio/ogg", "audio/wav",
            // Archives
            "application/zip", "application/x-rar-compressed", "application/x-7z-compressed",
            // Text
            "text/plain", "text/csv", "text/html"
        };
        
        return allowedTypes.Contains(mimeType.ToLower());
    }
    
    private string GenerateStorageKey(Guid messageId, string fileName)
    {
        var extension = Path.GetExtension(fileName);
        var timestamp = DateTime.UtcNow.ToString("yyyyMMddHHmmss");
        return $"chat-files/{messageId:N}/{timestamp}-{Guid.NewGuid():N}{extension}";
    }
}
