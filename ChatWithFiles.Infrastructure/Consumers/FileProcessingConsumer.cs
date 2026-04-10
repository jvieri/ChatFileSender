using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using ChatWithFiles.Domain.Interfaces;
using ChatWithFiles.Domain.Enums;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

namespace ChatWithFiles.Infrastructure.Consumers;

public class FileProcessingConsumer : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<FileProcessingConsumer> _logger;
    private readonly string _connectionString;
    private readonly int _maxConcurrentProcessing = 3;
    private readonly SemaphoreSlim _semaphore;
    
    public FileProcessingConsumer(
        IServiceProvider serviceProvider,
        ILogger<FileProcessingConsumer> logger,
        IConfiguration configuration)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
        _connectionString = configuration["RabbitMQ:ConnectionString"]!;
        _semaphore = new SemaphoreSlim(_maxConcurrentProcessing);
    }
    
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("FileProcessingConsumer starting...");

        var factory = new ConnectionFactory
        {
            Uri = new Uri(_connectionString),
            AutomaticRecoveryEnabled = true,
            NetworkRecoveryInterval = TimeSpan.FromSeconds(10)
        };

        // Retry connecting to RabbitMQ up to 5 times with back-off.
        // If RabbitMQ is not available, log a warning and exit gracefully
        // so the rest of the API keeps running.
        IConnection? connection = null;
        for (int attempt = 1; attempt <= 5; attempt++)
        {
            try
            {
                connection = await factory.CreateConnectionAsync(stoppingToken);
                break;
            }
            catch (Exception ex) when (!stoppingToken.IsCancellationRequested)
            {
                _logger.LogWarning(ex,
                    "FileProcessingConsumer: RabbitMQ connection attempt {Attempt}/5 failed", attempt);
                if (attempt == 5)
                {
                    _logger.LogWarning(
                        "FileProcessingConsumer: RabbitMQ unavailable after 5 attempts — consumer disabled");
                    return;
                }
                await Task.Delay(TimeSpan.FromSeconds(attempt * 2), stoppingToken);
            }
        }

        var channel = await connection!.CreateChannelAsync(cancellationToken: stoppingToken);
        
        // Declare queues
        await channel.QueueDeclareAsync(
            queue: "file-processing",
            durable: true,
            exclusive: false,
            autoDelete: false,
            arguments: new Dictionary<string, object>
            {
                ["x-dead-letter-exchange"] = "",
                ["x-dead-letter-routing-key"] = "file-processing-dlq"
            }
        );
        
        // Set prefetch count
        await channel.BasicQosAsync(prefetchSize: 0, prefetchCount: 10, global: false);
        
        var consumer = new AsyncEventingBasicConsumer(channel);
        consumer.ReceivedAsync += async (model, ea) =>
        {
            await _semaphore.WaitAsync(stoppingToken);
            
            try
            {
                await ProcessMessageAsync(channel, ea, stoppingToken);
            }
            finally
            {
                _semaphore.Release();
            }
        };
        
        await channel.BasicConsumeAsync(
            queue: "file-processing",
            autoAck: false,
            consumer: consumer
        );
        
        _logger.LogInformation("FileProcessingConsumer started successfully");
        
        // Keep running until cancellation
        while (!stoppingToken.IsCancellationRequested)
        {
            await Task.Delay(TimeSpan.FromSeconds(1), stoppingToken);
        }
    }
    
    private async Task ProcessMessageAsync(IChannel channel, BasicDeliverEventArgs eventArgs, CancellationToken ct)
    {
        var body = eventArgs.Body.ToArray();
        var message = Encoding.UTF8.GetString(body);
        var messageId = eventArgs.BasicProperties.MessageId;
        
        _logger.LogInformation("Processing file message {MessageId}: {Message}", messageId, message);
        
        try
        {
            using var scope = _serviceProvider.CreateScope();
            var fileRepository = scope.ServiceProvider.GetRequiredService<IFileAttachmentRepository>();
            var storageService = scope.ServiceProvider.GetRequiredService<IStorageService>();
            var chatHub = scope.ServiceProvider.GetRequiredService<IChatHubService>();
            var messageBus = scope.ServiceProvider.GetRequiredService<IMessageBus>();
            var unitOfWork = scope.ServiceProvider.GetRequiredService<IUnitOfWork>();
            
            var fileEvent = JsonSerializer.Deserialize<FileUploadedEvent>(message);
            if (fileEvent == null)
            {
                _logger.LogError("Failed to deserialize message {MessageId}", messageId);
                await channel.BasicNackAsync(deliveryTag: eventArgs.DeliveryTag, multiple: false, requeue: false, cancellationToken: ct);
                return;
            }
            
            // Get file attachment
            var fileAttachment = await fileRepository.GetByIdAsync(fileEvent.FileId, ct);
            if (fileAttachment == null)
            {
                _logger.LogError("File attachment {FileId} not found", fileEvent.FileId);
                await channel.BasicNackAsync(deliveryTag: eventArgs.DeliveryTag, multiple: false, requeue: false, cancellationToken: ct);
                return;
            }
            
            // Mark as processing
            fileAttachment.MarkAsProcessing();
            await unitOfWork.SaveChangesAsync(ct);
            
            try
            {
                // Process file (thumbnail, metadata extraction, etc.)
                var metadata = await storageService.GetFileMetadataAsync(fileAttachment.StorageKey, ct);
                
                // Extract metadata based on file type
                FileMetadata? extractedMetadata = null;
                string? thumbnailUrl = null;

                if (fileAttachment.FileType.StartsWith("image/"))
                {
                    extractedMetadata = await ExtractImageMetadataAsync();
                    // In real implementation, generate thumbnail here
                    // thumbnailUrl = await GenerateThumbnailAsync(fileAttachment.StorageKey);
                }
                else if (fileAttachment.FileType.StartsWith("video/"))
                {
                    extractedMetadata = await ExtractVideoMetadataAsync();
                    // Generate video thumbnail
                    // thumbnailUrl = await GenerateVideoThumbnailAsync(fileAttachment.StorageKey);
                }
                
                // Apply metadata
                if (extractedMetadata != null)
                {
                    if (extractedMetadata.Width.HasValue) fileAttachment.Width = extractedMetadata.Width;
                    if (extractedMetadata.Height.HasValue) fileAttachment.Height = extractedMetadata.Height;
                    if (extractedMetadata.Duration.HasValue) fileAttachment.Duration = extractedMetadata.Duration;
                }
                
                // Mark processing completed
                fileAttachment.MarkProcessingCompleted(thumbnailUrl);
                await unitOfWork.SaveChangesAsync(ct);
                
                // Notify via SignalR
                var chatId = GetChatId(fileAttachment.Message!);
                await chatHub.NotifyFileProcessingCompletedAsync(chatId, fileAttachment.Id, new
                {
                    fileId = fileAttachment.Id,
                    thumbnailUrl,
                    width = fileAttachment.Width,
                    height = fileAttachment.Height,
                    duration = fileAttachment.Duration
                });
                
                // Acknowledge message
                await channel.BasicAckAsync(deliveryTag: eventArgs.DeliveryTag, multiple: false, cancellationToken: ct);
                
                _logger.LogInformation("File {FileId} processed successfully", fileEvent.FileId);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing file {FileId}", fileEvent.FileId);
                
                fileAttachment.MarkProcessingFailed(ex.Message);
                await unitOfWork.SaveChangesAsync(ct);
                
                // Nack and send to DLQ if max retries exceeded
                if (fileAttachment.RetryCount >= fileAttachment.MaxRetries)
                {
                    await channel.BasicNackAsync(deliveryTag: eventArgs.DeliveryTag, multiple: false, requeue: false, cancellationToken: ct);
                }
                else
                {
                    await channel.BasicNackAsync(deliveryTag: eventArgs.DeliveryTag, multiple: false, requeue: true, cancellationToken: ct);
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Fatal error processing message {MessageId}", messageId);
            await channel.BasicNackAsync(deliveryTag: eventArgs.DeliveryTag, multiple: false, requeue: false, cancellationToken: ct);
        }
    }
    
    private Task<FileMetadata?> ExtractImageMetadataAsync()
    {
        // In real implementation, use ImageSharp or similar library
        return Task.FromResult<FileMetadata?>(new FileMetadata(
            Width: 1920,
            Height: 1080,
            Duration: null,
            BitRate: null,
            FrameRate: null
        ));
    }
    
    private Task<FileMetadata?> ExtractVideoMetadataAsync()
    {
        // In real implementation, use FFMpegCore or similar library
        return Task.FromResult<FileMetadata?>(new FileMetadata(
            Width: 1920,
            Height: 1080,
            Duration: 120,
            BitRate: 5000,
            FrameRate: 30.0
        ));
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
