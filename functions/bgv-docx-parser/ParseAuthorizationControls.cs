using System.Net;
using bgv_docx_parser.Models;
using bgv_docx_parser.Services;
using bgv_docx_parser.Utilities;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;

namespace bgv_docx_parser;

public class ParseAuthorizationControls
{
    private const int MaxRequestBodyBytes = 16 * 1024 * 1024;
    private const int MaxDocxBytes = 10 * 1024 * 1024;
    private const string HealthMessage = "Use POST with JSON { fileName, docxBase64 }.";
    private const string GuidanceNote =
        "Best practice: use SignedYes for the consent checkbox tag/title. CandidateAuthorisation remains supported for compatibility.";

    private readonly IDocxCheckboxExtractor _checkboxExtractor;
    private readonly IAuthorizationMatchEvaluator _matchEvaluator;
    private readonly IDrawingDetectionService _drawingDetectionService;
    private readonly ILogger<ParseAuthorizationControls> _logger;

    public ParseAuthorizationControls(
        IDocxCheckboxExtractor checkboxExtractor,
        IAuthorizationMatchEvaluator matchEvaluator,
        IDrawingDetectionService drawingDetectionService,
        ILoggerFactory loggerFactory)
    {
        _checkboxExtractor = checkboxExtractor;
        _matchEvaluator = matchEvaluator;
        _drawingDetectionService = drawingDetectionService;
        _logger = loggerFactory.CreateLogger<ParseAuthorizationControls>();
    }

    [Function("ParseAuthorizationControls")]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Function, "get", "post")] HttpRequestData req)
    {
        using IDisposable? requestScope = _logger.BeginScope(new Dictionary<string, object?>
        {
            ["FunctionName"] = "ParseAuthorizationControls",
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

        using IDisposable? fileScope = _logger.BeginScope(new Dictionary<string, object?>
        {
            ["FileName"] = payload?.FileName ?? "<unknown>"
        });

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

        IReadOnlyCollection<CheckboxControl> controlsFound;
        try
        {
            controlsFound = _checkboxExtractor.Extract(docBytes);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to parse DOCX");
            return await WriteErrorAsync(req, HttpStatusCode.BadRequest, "Failed to parse DOCX");
        }

        AuthorizationEvaluationResult evaluation = _matchEvaluator.Evaluate(controlsFound);
        DrawingDetectionResult drawingDetection = DrawingDetectionResult.Disabled;

        if (evaluation.SignedYesMatches.Count > 1)
        {
            _logger.LogWarning(
                "Found {MatchCount} SignedYes-compatible controls in {FileName}; aggregating with any-checked semantics.",
                evaluation.SignedYesMatches.Count,
                payload?.FileName ?? "<unknown>");
        }

        if (evaluation.SignedNoMatches.Count > 1)
        {
            _logger.LogWarning(
                "Found {MatchCount} SignedNo controls in {FileName}; aggregating with any-checked semantics.",
                evaluation.SignedNoMatches.Count,
                payload?.FileName ?? "<unknown>");
        }

        try
        {
            drawingDetection = _drawingDetectionService.Detect(docBytes);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Level A drawing detection failed; preserving checkbox response behavior.");
        }

        _logger.LogInformation(
            "DOCX parsed successfully. ControlsFound={ControlsFoundCount}, SignedYesMatches={SignedYesMatchCount}, SignedNoMatches={SignedNoMatchCount}, SignedYes={SignedYes}, SignedNo={SignedNo}, DrawingDetectionEnabled={DrawingDetectionEnabled}, DrawingSignatureDetected={DrawingSignatureDetected}, DrawingFindingsCount={DrawingFindingsCount}.",
            controlsFound.Count,
            evaluation.SignedYesMatches.Count,
            evaluation.SignedNoMatches.Count,
            evaluation.SignedYes,
            evaluation.SignedNo,
            drawingDetection.Enabled,
            drawingDetection.SignatureDetected,
            drawingDetection.Findings.Count);

        var responsePayload = new AuthorizationResponsePayload(
            payload?.FileName,
            evaluation.SignedYes,
            evaluation.SignedNo,
            controlsFound,
            GuidanceNote,
            drawingDetection);

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
