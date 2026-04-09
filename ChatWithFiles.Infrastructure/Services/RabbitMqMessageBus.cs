using System.Text;
using System.Text.Json;
using ChatWithFiles.Domain.Interfaces;
using RabbitMQ.Client;

namespace ChatWithFiles.Infrastructure.Services;

public class RabbitMqMessageBus : IMessageBus, IDisposable
{
    private readonly IConnection _connection;
    private readonly IChannel _channel;
    private bool _disposed;

    public RabbitMqMessageBus(string connectionString)
    {
        var factory = new ConnectionFactory
        {
            Uri = new Uri(connectionString),
            AutomaticRecoveryEnabled = true,
            NetworkRecoveryInterval = TimeSpan.FromSeconds(10)
        };

        _connection = factory.CreateConnectionAsync().GetAwaiter().GetResult();
        _channel = _connection.CreateChannelAsync().GetAwaiter().GetResult();

        // Declare common queues
        DeclareQueueAsync("file-processing").GetAwaiter().GetResult();
        DeclareQueueAsync("file-processing-results").GetAwaiter().GetResult();
        DeclareQueueAsync("file-processing-dlq").GetAwaiter().GetResult();
    }
    
    private async Task DeclareQueueAsync(string queueName)
    {
        var arguments = new Dictionary<string, object>();

        // Add dead letter exchange for failed messages
        if (queueName == "file-processing")
        {
            arguments["x-dead-letter-exchange"] = "";
            arguments["x-dead-letter-routing-key"] = "file-processing-dlq";
            arguments["x-message-ttl"] = 86400000; // 24 hours
        }

        await _channel.QueueDeclareAsync(
            queue: queueName,
            durable: true,
            exclusive: false,
            autoDelete: false,
            arguments: arguments.Count > 0 ? arguments : null
        );
    }

    public async Task PublishAsync<T>(T message, string queueName, CancellationToken ct = default) where T : class
    {
        await PublishAsync(message, new Dictionary<string, object>(), queueName, ct);
    }

    public async Task PublishAsync<T>(T message, Dictionary<string, object> headers, string queueName, CancellationToken ct = default) where T : class
    {
        var json = JsonSerializer.Serialize(message);
        var body = Encoding.UTF8.GetBytes(json);

        var properties = new BasicProperties
        {
            Persistent = true,
            MessageId = Guid.NewGuid().ToString(),
            Timestamp = new AmqpTimestamp(DateTimeOffset.UtcNow.ToUnixTimeSeconds()),
            Type = typeof(T).Name,
            Headers = new Dictionary<string, object?>()
        };

        // Add custom headers
        foreach (var (key, value) in headers)
        {
            properties.Headers[key] = value;
        }

        // Ensure queue exists
        await _channel.QueueDeclarePassiveAsync(queueName, cancellationToken: ct);

        await _channel.BasicPublishAsync(
            exchange: "",
            routingKey: queueName,
            mandatory: false,
            basicProperties: properties,
            body: body,
            cancellationToken: ct
        );
    }

    public void Dispose()
    {
        if (_disposed) return;

        _channel?.CloseAsync();
        _connection?.CloseAsync();
        _channel?.Dispose();
        _connection?.Dispose();
        _disposed = true;
    }
}
