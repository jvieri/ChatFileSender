using Microsoft.AspNetCore.Mvc;
using MediatR;
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
