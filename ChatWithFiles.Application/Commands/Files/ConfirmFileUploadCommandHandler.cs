using ChatWithFiles.Contracts.Files;
using ChatWithFiles.Domain.Enums;
using ChatWithFiles.Domain.Interfaces;
using MediatR;

namespace ChatWithFiles.Application.Commands.Files;

public class ConfirmFileUploadCommandHandler : IRequestHandler<ConfirmFileUploadCommand, ConfirmFileUploadResponse>
{
    private readonly IFileAttachmentRepository _fileRepository;
    private readonly IStorageService _storageService;
    private readonly IMessageBus _messageBus;
    private readonly IChatHubService _chatHub;
    private readonly IUnitOfWork _unitOfWork;
    
    public ConfirmFileUploadCommandHandler(
        IFileAttachmentRepository fileRepository,
        IStorageService storageService,
        IMessageBus messageBus,
        IChatHubService chatHub,
        IUnitOfWork unitOfWork)
    {
        _fileRepository = fileRepository;
        _storageService = storageService;
        _messageBus = messageBus;
        _chatHub = chatHub;
        _unitOfWork = unitOfWork;
    }
    
    public async Task<ConfirmFileUploadResponse> Handle(ConfirmFileUploadCommand request, CancellationToken cancellationToken)
    {
        // 1. Get file attachment
        var fileAttachment = await _fileRepository.GetByIdAsync(request.FileId, cancellationToken);
        
        if (fileAttachment == null)
        {
            throw new KeyNotFoundException($"File attachment {request.FileId} not found");
        }
        
        // 2. Verify file exists in storage
        var fileExists = await _storageService.FileExistsAsync(fileAttachment.StorageKey, cancellationToken);
        if (!fileExists)
        {
            throw new InvalidOperationException($"File not found in storage: {fileAttachment.StorageKey}");
        }
        
        // 3. Get actual file size from storage metadata
        var metadata = await _storageService.GetFileMetadataAsync(fileAttachment.StorageKey, cancellationToken);
        var actualFileSize = Convert.ToInt64(metadata.GetValueOrDefault("ContentLength", fileAttachment.FileSize));
        
        // 4. Update file status to Uploaded
        fileAttachment.MarkAsUploaded(fileAttachment.StorageKey, actualFileSize);
        await _fileRepository.UpdateAsync(fileAttachment, cancellationToken);
        
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        await _unitOfWork.CommitTransactionAsync(cancellationToken);
        
        // 5. Notify via SignalR that file is uploaded
        var chatId = GetChatId(fileAttachment.Message!);
        await _chatHub.NotifyFileUploadProgressAsync(
            request.UserId.ToString(),
            request.FileId,
            100,
            "Uploaded"
        );
        
        // 6. Publish event to RabbitMQ for background processing
        await _messageBus.PublishAsync(new FileUploadedEvent(
            fileAttachment.Id,
            fileAttachment.MessageId,
            fileAttachment.FileType,
            fileAttachment.StorageKey,
            fileAttachment.FileSize
        ), "file-processing", cancellationToken);
        
        return new ConfirmFileUploadResponse(
            request.FileId,
            "Processing"
        );
    }
    
    private string GetChatId(ChatWithFiles.Domain.Entities.ChatMessage message)
    {
        if (message.GroupId.HasValue)
        {
            return $"group_{message.GroupId.Value:N}";
        }
        
        return $"direct_{message.SenderId:N}_{message.ReceiverId:N}";
    }
}

public record FileUploadedEvent(
    Guid FileId,
    Guid MessageId,
    string FileType,
    string StorageKey,
    long FileSize
);
