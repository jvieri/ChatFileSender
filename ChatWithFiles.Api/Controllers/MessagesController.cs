using Microsoft.AspNetCore.Mvc;
using MediatR;
using ChatWithFiles.Application.Commands.Messages;
using ChatWithFiles.Application.Queries.Messages;
using ChatWithFiles.Contracts.Files;
using ChatWithFiles.Contracts.Messages;
using ChatWithFiles.Domain.Interfaces;

namespace ChatWithFiles.Api.Controllers;

[ApiController]
[Route("api/v1/[controller]")]
[Produces("application/json")]
public class MessagesController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly ICurrentUserAccessor _currentUser;
    private readonly ILogger<MessagesController> _logger;
    
    public MessagesController(
        IMediator mediator,
        ICurrentUserAccessor currentUser,
        ILogger<MessagesController> logger)
    {
        _mediator = mediator;
        _currentUser = currentUser;
        _logger = logger;
    }
    
    /// <summary>
    /// Send a text message
    /// </summary>
    [HttpPost]
    [ProducesResponseType(typeof(ChatMessageDto), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> SendMessage(
        [FromBody] SendMessageRequest request,
        CancellationToken cancellationToken)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(request.TextContent))
            {
                return BadRequest(new { error = "Message content is required" });
            }
            
            var command = new SendMessageCommand(
                _currentUser.UserId,
                _currentUser.UserName,
                request.ReceiverId,
                request.GroupId,
                request.TextContent.Trim()
            );
            
            var result = await _mediator.Send(command, cancellationToken);
            return CreatedAtAction(nameof(GetMessage), new { id = result.Id }, result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error sending message");
            return StatusCode(500, new { error = ex.Message });
        }
    }
    
    /// <summary>
    /// Create a new message with file attachments
    /// </summary>
    [HttpPost("with-file")]
    [ProducesResponseType(typeof(CreateMessageWithFileResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> CreateMessageWithFile(
        [FromBody] CreateMessageWithFileRequest request,
        CancellationToken cancellationToken)
    {
        try
        {
            if (request.Files == null || !request.Files.Any())
            {
                return BadRequest(new { error = "At least one file is required" });
            }
            
            var command = new CreateMessageWithFileCommand(
                _currentUser.UserId,
                request.ReceiverId,
                request.GroupId,
                request.TextContent,
                request.Files
            );
            
            var result = await _mediator.Send(command, cancellationToken);
            return CreatedAtAction(nameof(GetMessage), new { id = result.MessageId }, result);
        }
        catch (ArgumentException ex)
        {
            _logger.LogWarning(ex, "Invalid file in message creation");
            return BadRequest(new { error = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating message with file");
            return StatusCode(500, new { error = ex.Message });
        }
    }
    
    /// <summary>
    /// Get a message by ID
    /// </summary>
    [HttpGet("{id}")]
    [ProducesResponseType(typeof(ChatMessageDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetMessage(
        Guid id,
        CancellationToken cancellationToken)
    {
        // Implementation would fetch from database
        return Ok(new ChatMessageDto(
            id,
            _currentUser.UserId,
            null,
            null,
            "Sample message",
            "Text",
            "Sent",
            new List<ChatWithFiles.Contracts.Files.FileAttachmentDto>(),
            DateTime.UtcNow
        ));
    }
    
    /// <summary>
    /// Get messages for a user or group
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(GetMessagesResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetMessages(
        [FromQuery] Guid? userId = null,
        [FromQuery] Guid? groupId = null,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50,
        CancellationToken cancellationToken = default)
    {
        var query = new GetMessagesQuery(_currentUser.UserId, userId, groupId, page, pageSize);
        var result = await _mediator.Send(query, cancellationToken);
        return Ok(result);
    }
}
