namespace ChatWithFiles.Contracts.Messages;

public record ChatMessageDto(
    Guid Id,
    Guid SenderId,
    Guid? ReceiverId,
    Guid? GroupId,
    string? TextContent,
    string MessageType,
    string Status,
    List<Contracts.Files.FileAttachmentDto> Attachments,
    DateTime CreatedAt
);

public record SendMessageRequest(
    Guid? ReceiverId = null,
    Guid? GroupId = null,
    string? TextContent = null
);

public record GetMessagesRequest(
    Guid? UserId = null,
    Guid? GroupId = null,
    int Page = 1,
    int PageSize = 50
);

public record GetMessagesResponse(
    List<ChatMessageDto> Messages,
    int TotalCount,
    int Page,
    int PageSize
);
