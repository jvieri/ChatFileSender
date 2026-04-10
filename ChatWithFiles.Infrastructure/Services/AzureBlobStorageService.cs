using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;
using Azure.Storage.Sas;
using ChatWithFiles.Domain.Interfaces;

namespace ChatWithFiles.Infrastructure.Services;

public class AzureBlobStorageService : IStorageService, IDisposable
{
    private readonly BlobServiceClient _blobServiceClient;
    private readonly string _containerName;
    private readonly string _accountKey;
    private readonly string _accountName;
    private bool _disposed;
    
    public AzureBlobStorageService(string connectionString, string containerName)
    {
        _blobServiceClient = new BlobServiceClient(connectionString);
        _containerName = containerName;
        
        // Extract account info for SAS generation.
        // Use Substring instead of Split('=')[1] because the AccountKey value
        // contains '=' characters (base64 padding) that Split would truncate.
        var parts = connectionString.Split(';');
        var namePart = parts.First(p => p.StartsWith("AccountName="));
        var keyPart  = parts.First(p => p.StartsWith("AccountKey="));
        _accountName = namePart.Substring("AccountName=".Length);
        _accountKey  = keyPart.Substring("AccountKey=".Length);
    }
    
    public Task<string> GenerateUploadUrlAsync(string storageKey, TimeSpan expiration, long maxSize, CancellationToken ct = default)
    {
        // The SAS token is computed purely from the account key (HMAC) — no network
        // call needed.  Avoid CreateIfNotExistsAsync which hits Azurite and fails
        // when Azurite's supported API version is older than the SDK's version.
        var containerClient = _blobServiceClient.GetBlobContainerClient(_containerName);
        var blobClient = containerClient.GetBlobClient(storageKey);

        var sasBuilder = new BlobSasBuilder
        {
            BlobContainerName = _containerName,
            BlobName = storageKey,
            Resource = "b",
            StartsOn = DateTimeOffset.UtcNow,
            ExpiresOn = DateTimeOffset.UtcNow.Add(expiration)
        };

        sasBuilder.SetPermissions(BlobSasPermissions.Write | BlobSasPermissions.Create);

        var sasToken = sasBuilder.ToSasQueryParameters(
            new Azure.Storage.StorageSharedKeyCredential(_accountName, _accountKey)
        ).ToString();

        return Task.FromResult($"{blobClient.Uri}?{sasToken}");
    }
    
    public async Task<string> GenerateDownloadUrlAsync(string storageKey, TimeSpan expiration, CancellationToken ct = default)
    {
        var containerClient = _blobServiceClient.GetBlobContainerClient(_containerName);
        var blobClient = containerClient.GetBlobClient(storageKey);
        
        var sasBuilder = new BlobSasBuilder
        {
            BlobContainerName = _containerName,
            BlobName = storageKey,
            Resource = "b",
            StartsOn = DateTimeOffset.UtcNow,
            ExpiresOn = DateTimeOffset.UtcNow.Add(expiration)
        };
        
        sasBuilder.SetPermissions(BlobSasPermissions.Read);
        
        var sasToken = sasBuilder.ToSasQueryParameters(
            new Azure.Storage.StorageSharedKeyCredential(_accountName, _accountKey)
        ).ToString();
        
        return $"{blobClient.Uri}?{sasToken}";
    }
    
    public async Task<bool> FileExistsAsync(string storageKey, CancellationToken ct = default)
    {
        var containerClient = _blobServiceClient.GetBlobContainerClient(_containerName);
        var blobClient = containerClient.GetBlobClient(storageKey);
        
        var exists = await blobClient.ExistsAsync(ct);
        return exists.Value;
    }
    
    public async Task DeleteFileAsync(string storageKey, CancellationToken ct = default)
    {
        var containerClient = _blobServiceClient.GetBlobContainerClient(_containerName);
        var blobClient = containerClient.GetBlobClient(storageKey);
        
        await blobClient.DeleteIfExistsAsync(cancellationToken: ct);
    }
    
    public async Task<Dictionary<string, object>> GetFileMetadataAsync(string storageKey, CancellationToken ct = default)
    {
        var containerClient = _blobServiceClient.GetBlobContainerClient(_containerName);
        var blobClient = containerClient.GetBlobClient(storageKey);
        
        var properties = await blobClient.GetPropertiesAsync(cancellationToken: ct);
        
        return new Dictionary<string, object>
        {
            ["ContentLength"] = properties.Value.ContentLength,
            ["ContentType"] = properties.Value.ContentType,
            ["LastModified"] = properties.Value.LastModified
        };
    }
    
    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
    }
}
