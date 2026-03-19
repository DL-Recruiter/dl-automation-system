using System.Net;
using bgv_docx_parser.Models;
using bgv_docx_parser.Services;
using bgv_docx_parser.Utilities;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;

namespace bgv_docx_parser;

public class FillReportSummaryControls
{
    private const int MaxRequestBodyBytes = 16 * 1024 * 1024;
    private const int MaxDocxBytes = 10 * 1024 * 1024;
    private const string HealthMessage = "Use POST with JSON { fileName, docxBase64, form1RawJson, form2RawJson }.";
    private const string Note =
        "Report summary content controls were populated from Form 1 and Form 2 raw response payloads.";

    private readonly IDocxContentControlValueFiller _valueFiller;
    private readonly IReportSummaryValueMapper _valueMapper;
    private readonly ILogger<FillReportSummaryControls> _logger;

    public FillReportSummaryControls(
        IDocxContentControlValueFiller valueFiller,
        IReportSummaryValueMapper valueMapper,
        ILoggerFactory loggerFactory)
    {
        _valueFiller = valueFiller;
        _valueMapper = valueMapper;
        _logger = loggerFactory.CreateLogger<FillReportSummaryControls>();
    }

    [Function("FillReportSummaryControls")]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", "post")] HttpRequestData req)
    {
        if (req.Method.Equals("GET", StringComparison.OrdinalIgnoreCase))
        {
            return await WriteJsonAsync(req, HttpStatusCode.OK, new { status = "ok", message = HealthMessage });
        }

        byte[] requestBytes;
        try
        {
            requestBytes = await RequestBodyReader.ReadAsync(req.Body, MaxRequestBodyBytes);
        }
        catch (InvalidDataException)
        {
            return await WriteErrorAsync(req, HttpStatusCode.RequestEntityTooLarge, $"Request body exceeds {MaxRequestBodyBytes} bytes.");
        }

        ReportSummaryFillRequestPayload? payload;
        try
        {
            payload = System.Text.Json.JsonSerializer.Deserialize<ReportSummaryFillRequestPayload>(
                requestBytes,
                FunctionJson.Options);
        }
        catch (System.Text.Json.JsonException)
        {
            return await WriteErrorAsync(req, HttpStatusCode.BadRequest, "Invalid JSON");
        }

        string? normalizedBase64 = Base64Utilities.Normalize(payload?.DocxBase64);
        if (string.IsNullOrEmpty(normalizedBase64))
        {
            return await WriteErrorAsync(req, HttpStatusCode.BadRequest, "Missing docxBase64");
        }

        if (!Base64Utilities.TryEstimateDecodedLength(normalizedBase64, out int estimatedDocxBytes))
        {
            return await WriteErrorAsync(req, HttpStatusCode.BadRequest, "docxBase64 is not valid base64");
        }

        if (estimatedDocxBytes > MaxDocxBytes)
        {
            return await WriteErrorAsync(req, HttpStatusCode.RequestEntityTooLarge, $"Decoded DOCX exceeds {MaxDocxBytes} bytes.");
        }

        byte[] docBytes;
        try
        {
            docBytes = Convert.FromBase64String(normalizedBase64);
        }
        catch (FormatException)
        {
            return await WriteErrorAsync(req, HttpStatusCode.BadRequest, "docxBase64 is not valid base64");
        }

        IReadOnlyDictionary<string, string> mappings = _valueMapper.BuildMappings(payload?.Form1RawJson, payload?.Form2RawJson);

        (byte[] filledDocxBytes, int filledControlsCount) fillResult;
        try
        {
            fillResult = _valueFiller.Fill(docBytes, mappings);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to fill report summary DOCX content controls.");
            return await WriteErrorAsync(req, HttpStatusCode.BadRequest, "Failed to fill report summary DOCX content controls");
        }

        var responsePayload = new ReportSummaryFillResponsePayload(
            payload?.FileName,
            fillResult.filledControlsCount,
            Convert.ToBase64String(fillResult.filledDocxBytes),
            mappings.Keys.OrderBy(static key => key, StringComparer.OrdinalIgnoreCase).ToArray(),
            Note);

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
