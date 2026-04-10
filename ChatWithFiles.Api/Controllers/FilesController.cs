using Microsoft.AspNetCore.Mvc;
using MediatR;
using Microsoft.AspNetCore.Http.Features;
using ChatWithFiles.Application.Commands.Messages;
using ChatWithFiles.Application.Commands.Files;
using ChatWithFiles.Application.Queries.Files;
using ChatWithFiles.Contracts.Files;
using ChatWithFiles.Domain.Interfaces;

namespace ChatWithFiles.Api.Controllers;

[ApiController]
[Route("api/v1/[controller]")]
[Produces("application/json")]
public class FilesController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly ICurrentUserAccessor _currentUser;
    private readonly ILogger<FilesController> _logger;
    
    public FilesController(
        IMediator mediator,
        ICurrentUserAccessor currentUser,
        ILogger<FilesController> logger)
    {
        _mediator = mediator;
        _currentUser = currentUser;
        _logger = logger;
    }
    
    /// <summary>
    /// Confirm that a file has been uploaded successfully
    /// </summary>
    [HttpPost("{fileId}/confirm")]
    [ProducesResponseType(typeof(ConfirmFileUploadResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> ConfirmFileUpload(
        Guid fileId,
        [FromBody] ConfirmFileUploadRequest request,
        CancellationToken cancellationToken)
    {
        try
        {
            var command = new ConfirmFileUploadCommand(
                fileId,
                _currentUser.UserId,
                request.Checksum
            );
            
            var result = await _mediator.Send(command, cancellationToken);
            return Ok(result);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning(ex, "File {FileId} not found", fileId);
            return NotFound(new { error = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error confirming file upload {FileId}", fileId);
            return BadRequest(new { error = ex.Message });
        }
    }
    
    /// <summary>
    /// Get download URL for a file
    /// </summary>
    [HttpGet("{fileId}/download-url")]
    [ProducesResponseType(typeof(FileDownloadUrlResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetDownloadUrl(
        Guid fileId,
        CancellationToken cancellationToken)
    {
        try
        {
            var query = new GetFileDownloadUrlQuery(fileId, _currentUser.UserId);
            var result = await _mediator.Send(query, cancellationToken);
            return Ok(result);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { error = ex.Message });
        }
        catch (UnauthorizedAccessException ex)
        {
            return Forbid(ex.Message);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting download URL for file {FileId}", fileId);
            return StatusCode(500, new { error = ex.Message });
        }
    }
    
    /// <summary>
    /// Direct upload (demo): client sends bytes straight to the API, no Azurite presigned URL needed.
    /// </summary>
    [HttpPost("{fileId}/upload-bytes")]
    [DisableRequestSizeLimit]
    [RequestFormLimits(MultipartBodyLengthLimit = 110_000_000)]
    public async Task<IActionResult> UploadBytes(
        Guid fileId,
        IFormFile file,
        [FromServices] IFileAttachmentRepository fileRepository,
        [FromServices] IChatHubService chatHub,
        [FromServices] IUnitOfWork unitOfWork,
        CancellationToken cancellationToken)
    {
        try
        {
            var attachment = await fileRepository.GetByIdAsync(fileId, cancellationToken);
            if (attachment == null)
                return NotFound(new { error = $"File attachment {fileId} not found" });

            // Save file bytes to local temp storage so the download endpoint can serve them
            var localPath = GetLocalStoragePath(attachment.StorageKey);
            Directory.CreateDirectory(Path.GetDirectoryName(localPath)!);
            await using (var fs = System.IO.File.Create(localPath))
            {
                await file.CopyToAsync(fs, cancellationToken);
            }

            await fileRepository.MarkAsUploadedAsync(
                fileId, attachment.StorageKey, file.Length, cancellationToken);
            await unitOfWork.SaveChangesAsync(cancellationToken);

            await chatHub.NotifyFileUploadProgressAsync(
                attachment.UploadedBy.ToString(), fileId, 100, "Uploaded");

            _logger.LogInformation(
                "Direct upload OK — FileId={FileId} Size={Size}", fileId, file.Length);

            return Ok(new { fileId, status = "Uploaded", size = file.Length });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Direct upload failed for FileId={FileId}", fileId);
            return StatusCode(500, new { error = ex.Message });
        }
    }

    /// <summary>
    /// Download a previously uploaded file (demo: served from local temp storage).
    /// </summary>
    [HttpGet("{fileId}/download")]
    public async Task<IActionResult> Download(
        Guid fileId,
        [FromServices] IFileAttachmentRepository fileRepository,
        CancellationToken cancellationToken)
    {
        try
        {
            var attachment = await fileRepository.GetByIdAsync(fileId, cancellationToken);
            if (attachment == null)
                return NotFound(new { error = $"File attachment {fileId} not found" });

            var localPath = GetLocalStoragePath(attachment.StorageKey);
            if (!System.IO.File.Exists(localPath))
                return NotFound(new { error = "File data not found in storage" });

            var stream = System.IO.File.OpenRead(localPath);
            var contentType = string.IsNullOrWhiteSpace(attachment.FileType)
                ? "application/octet-stream"
                : attachment.FileType;
            var fileName = attachment.OriginalFileName ?? attachment.FileName;

            return File(stream, contentType, fileName);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Download failed for FileId={FileId}", fileId);
            return StatusCode(500, new { error = ex.Message });
        }
    }

    private static string GetLocalStoragePath(string storageKey)
    {
        // storageKey is e.g. "chat-files/{messageId}/{timestamp}-{guid}.ext"
        // Store under %TEMP%/chatfiles-demo/ preserving the sub-path.
        var basePath = Path.Combine(Path.GetTempPath(), "chatfiles-demo");
        // Normalise forward slashes to OS separator
        var relative = storageKey.Replace('/', Path.DirectorySeparatorChar);
        return Path.Combine(basePath, relative);
    }

    /// <summary>
    /// Retry a failed file upload
    /// </summary>
    [HttpPost("{fileId}/retry")]
    [ProducesResponseType(typeof(RetryFileUploadResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> RetryFileUpload(
        Guid fileId,
        CancellationToken cancellationToken)
    {
        try
        {
            // Implementation would create a new upload session
            // For now, returning placeholder
            return Ok(new RetryFileUploadResponse(
                fileId,
                "https://storage.example.com/new-upload-url",
                DateTime.UtcNow.AddHours(1)
            ));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrying file upload {FileId}", fileId);
            return BadRequest(new { error = ex.Message });
        }
    }
}
