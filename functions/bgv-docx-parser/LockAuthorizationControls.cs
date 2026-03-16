using System.Net;
using bgv_docx_parser.Models;
using bgv_docx_parser.Services;
using bgv_docx_parser.Utilities;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;

namespace bgv_docx_parser;

public class LockAuthorizationControls
{
    private const int MaxRequestBodyBytes = 16 * 1024 * 1024;
    private const int MaxDocxBytes = 10 * 1024 * 1024;
    private const string HealthMessage = "Use POST with JSON { fileName, docxBase64 }.";
    private const string LockNote =
        "All content controls are locked with sdtContentLocked to prevent editing/deletion in Developer mode.";

    private readonly IDocxContentControlLocker _contentControlLocker;
    private readonly ILogger<LockAuthorizationControls> _logger;

    public LockAuthorizationControls(
        IDocxContentControlLocker contentControlLocker,
        ILoggerFactory loggerFactory)
    {
        _contentControlLocker = contentControlLocker;
        _logger = loggerFactory.CreateLogger<LockAuthorizationControls>();
    }

    [Function("LockAuthorizationControls")]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Function, "get", "post")] HttpRequestData req)
    {
        using IDisposable? requestScope = _logger.BeginScope(new Dictionary<string, object?>
        {
            ["FunctionName"] = "LockAuthorizationControls",
            ["Method"] = req.Method
        });

        if (req.Method.Equals("GET", StringComparison.OrdinalIgnoreCase))
        {
            _logger.LogInformation("Health check request received.");
            return await WriteJsonAsync(
                req,
                HttpStatusCode.OK,
                new
                {
                    status = "ok",
                    message = HealthMessage
                });
        }

        byte[] requestBytes;
        try
        {
            requestBytes = await RequestBodyReader.ReadAsync(req.Body, MaxRequestBodyBytes);
        }
        catch (InvalidDataException)
        {
            _logger.LogWarning(
                "Request body exceeded the maximum allowed size of {MaxRequestBodyBytes} bytes.",
                MaxRequestBodyBytes);
            return await WriteErrorAsync(
                req,
                HttpStatusCode.RequestEntityTooLarge,
                $"Request body exceeds {MaxRequestBodyBytes} bytes.");
        }

        AuthorizationRequestPayload? payload;
        try
        {
            payload = System.Text.Json.JsonSerializer.Deserialize<AuthorizationRequestPayload>(
                requestBytes,
                FunctionJson.Options);
        }
        catch (System.Text.Json.JsonException)
        {
            _logger.LogWarning("Invalid JSON received.");
            return await WriteErrorAsync(req, HttpStatusCode.BadRequest, "Invalid JSON");
        }

        string? normalizedBase64 = Base64Utilities.Normalize(payload?.DocxBase64);
        if (string.IsNullOrEmpty(normalizedBase64))
        {
            _logger.LogWarning("Request is missing docxBase64.");
            return await WriteErrorAsync(req, HttpStatusCode.BadRequest, "Missing docxBase64");
        }

        if (!Base64Utilities.TryEstimateDecodedLength(normalizedBase64, out int estimatedDocxBytes))
        {
            _logger.LogWarning("docxBase64 failed decoded-length validation.");
            return await WriteErrorAsync(req, HttpStatusCode.BadRequest, "docxBase64 is not valid base64");
        }

        if (estimatedDocxBytes > MaxDocxBytes)
        {
            _logger.LogWarning(
                "Estimated decoded DOCX size {EstimatedDocxBytes} exceeds the maximum allowed size of {MaxDocxBytes} bytes.",
                estimatedDocxBytes,
                MaxDocxBytes);
            return await WriteErrorAsync(
                req,
                HttpStatusCode.RequestEntityTooLarge,
                $"Decoded DOCX exceeds {MaxDocxBytes} bytes.");
        }

        byte[] docBytes;
        try
        {
            docBytes = Convert.FromBase64String(normalizedBase64);
        }
        catch (FormatException)
        {
            _logger.LogWarning("docxBase64 failed base64 decoding.");
            return await WriteErrorAsync(req, HttpStatusCode.BadRequest, "docxBase64 is not valid base64");
        }

        if (docBytes.Length > MaxDocxBytes)
        {
            _logger.LogWarning(
                "Decoded DOCX size {DocxBytesLength} exceeds the maximum allowed size of {MaxDocxBytes} bytes.",
                docBytes.Length,
                MaxDocxBytes);
            return await WriteErrorAsync(
                req,
                HttpStatusCode.RequestEntityTooLarge,
                $"Decoded DOCX exceeds {MaxDocxBytes} bytes.");
        }

        (byte[] lockedDocxBytes, int lockedControlsCount) lockResult;
        try
        {
            lockResult = _contentControlLocker.LockAll(docBytes);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to lock DOCX content controls.");
            return await WriteErrorAsync(req, HttpStatusCode.BadRequest, "Failed to lock DOCX content controls");
        }

        string lockedDocxBase64 = Convert.ToBase64String(lockResult.Item1);

        _logger.LogInformation(
            "DOCX content controls locked successfully. LockedControlsCount={LockedControlsCount}.",
            lockResult.Item2);

        var responsePayload = new LockContentControlsResponsePayload(
            payload?.FileName,
            lockResult.Item2,
            lockedDocxBase64,
            LockNote);

        return await WriteJsonAsync(req, HttpStatusCode.OK, responsePayload);
    }

    private static async Task<HttpResponseData> WriteErrorAsync(
        HttpRequestData req,
        HttpStatusCode statusCode,
        string message)
    {
        return await WriteJsonAsync(req, statusCode, new { error = message });
    }

    private static async Task<HttpResponseData> WriteJsonAsync(
        HttpRequestData req,
        HttpStatusCode statusCode,
        object payload)
    {
        HttpResponseData response = req.CreateResponse(statusCode);
        response.Headers.Add("Content-Type", "application/json; charset=utf-8");
        await response.WriteStringAsync(System.Text.Json.JsonSerializer.Serialize(payload, FunctionJson.Options));
        return response;
    }
}
