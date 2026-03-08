using System.Net;
using System.Text.Json;
using DocumentFormat.OpenXml;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;

namespace bgv_docx_parser;

public class ParseAuthorizationControls
{
    private const int MaxRequestBodyBytes = 16 * 1024 * 1024;
    private const int MaxDocxBytes = 10 * 1024 * 1024;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    private static readonly string[] SignedYesIdentifiers =
    [
        "SignedYes",
        "CandidateAuthorisation"
    ];

    private readonly ILogger<ParseAuthorizationControls> _logger;

    public ParseAuthorizationControls(ILoggerFactory loggerFactory)
    {
        _logger = loggerFactory.CreateLogger<ParseAuthorizationControls>();
    }

    private sealed record RequestPayload(string? FileName, string? DocxBase64);

    private sealed record CheckboxControl(string? Tag, string? Title, bool IsChecked);

    private sealed record ResponsePayload(
        string? FileName,
        bool? SignedYes,
        bool? SignedNo,
        IReadOnlyCollection<CheckboxControl> ControlsFound,
        string Note);

    [Function("ParseAuthorizationControls")]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Function, "get", "post")] HttpRequestData req)
    {
        if (req.Method.Equals("GET", StringComparison.OrdinalIgnoreCase))
        {
            return await WriteJsonAsync(
                req,
                HttpStatusCode.OK,
                new
                {
                    status = "ok",
                    message = "Use POST with JSON { fileName, docxBase64 }."
                });
        }

        byte[] requestBytes;
        try
        {
            requestBytes = await ReadRequestBodyAsync(req.Body, MaxRequestBodyBytes);
        }
        catch (InvalidDataException)
        {
            return await WriteErrorAsync(
                req,
                HttpStatusCode.RequestEntityTooLarge,
                $"Request body exceeds {MaxRequestBodyBytes} bytes.");
        }

        RequestPayload? payload;
        try
        {
            payload = JsonSerializer.Deserialize<RequestPayload>(requestBytes, JsonOptions);
        }
        catch (JsonException)
        {
            return await WriteErrorAsync(req, HttpStatusCode.BadRequest, "Invalid JSON");
        }

        string? normalizedBase64 = NormalizeBase64(payload?.DocxBase64);
        if (string.IsNullOrEmpty(normalizedBase64))
        {
            return await WriteErrorAsync(req, HttpStatusCode.BadRequest, "Missing docxBase64");
        }

        if (!TryEstimateDecodedLength(normalizedBase64, out int estimatedDocxBytes))
        {
            return await WriteErrorAsync(req, HttpStatusCode.BadRequest, "docxBase64 is not valid base64");
        }

        if (estimatedDocxBytes > MaxDocxBytes)
        {
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
            return await WriteErrorAsync(req, HttpStatusCode.BadRequest, "docxBase64 is not valid base64");
        }

        if (docBytes.Length > MaxDocxBytes)
        {
            return await WriteErrorAsync(
                req,
                HttpStatusCode.RequestEntityTooLarge,
                $"Decoded DOCX exceeds {MaxDocxBytes} bytes.");
        }

        List<CheckboxControl> controlsFound;
        try
        {
            controlsFound = ExtractCheckboxControls(docBytes);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to parse DOCX");
            return await WriteErrorAsync(req, HttpStatusCode.BadRequest, "Failed to parse DOCX");
        }

        List<CheckboxControl> signedYesMatches = FindSignedYesMatches(controlsFound);
        List<CheckboxControl> signedNoMatches = FindExactMatches(controlsFound, "SignedNo");

        if (signedYesMatches.Count > 1)
        {
            _logger.LogWarning(
                "Found {MatchCount} SignedYes-compatible controls in {FileName}; aggregating with any-checked semantics.",
                signedYesMatches.Count,
                payload?.FileName ?? "<unknown>");
        }

        if (signedNoMatches.Count > 1)
        {
            _logger.LogWarning(
                "Found {MatchCount} SignedNo controls in {FileName}; aggregating with any-checked semantics.",
                signedNoMatches.Count,
                payload?.FileName ?? "<unknown>");
        }

        var responsePayload = new ResponsePayload(
            payload?.FileName,
            SummarizeState(signedYesMatches),
            SummarizeState(signedNoMatches),
            controlsFound,
            "Best practice: use SignedYes for the consent checkbox tag/title. CandidateAuthorisation remains supported for compatibility.");

        return await WriteJsonAsync(req, HttpStatusCode.OK, responsePayload);
    }

    private static async Task<byte[]> ReadRequestBodyAsync(Stream stream, int maxBytes)
    {
        using var output = new MemoryStream();
        byte[] buffer = new byte[81920];
        int totalBytes = 0;

        while (true)
        {
            int read = await stream.ReadAsync(buffer.AsMemory(0, buffer.Length));
            if (read == 0)
            {
                break;
            }

            totalBytes += read;
            if (totalBytes > maxBytes)
            {
                throw new InvalidDataException("Request body too large.");
            }

            output.Write(buffer, 0, read);
        }

        return output.ToArray();
    }

    private static string? NormalizeBase64(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    }

    private static bool TryEstimateDecodedLength(string base64, out int decodedLength)
    {
        decodedLength = 0;

        if (base64.Length == 0 || base64.Length % 4 != 0)
        {
            return false;
        }

        int padding = 0;
        if (base64.EndsWith("==", StringComparison.Ordinal))
        {
            padding = 2;
        }
        else if (base64.EndsWith('='))
        {
            padding = 1;
        }

        long estimatedLength = ((long)base64.Length / 4 * 3) - padding;
        if (estimatedLength < 0 || estimatedLength > int.MaxValue)
        {
            return false;
        }

        decodedLength = (int)estimatedLength;
        return true;
    }

    private static List<CheckboxControl> ExtractCheckboxControls(byte[] docBytes)
    {
        using var stream = new MemoryStream(docBytes);
        using var doc = WordprocessingDocument.Open(stream, false);

        IEnumerable<SdtElement> sdtNodes = doc.MainDocumentPart?.Document?.Descendants<SdtElement>()
            ?? Enumerable.Empty<SdtElement>();

        var controls = new List<CheckboxControl>();

        foreach (SdtElement sdt in sdtNodes)
        {
            bool? isChecked = TryGetCheckboxState(sdt);
            if (isChecked is null)
            {
                continue;
            }

            string? tag = sdt.SdtProperties?.GetFirstChild<Tag>()?.Val?.Value;
            string? title = sdt.SdtProperties?.GetFirstChild<SdtAlias>()?.Val?.Value;
            controls.Add(new CheckboxControl(tag, title, isChecked.Value));
        }

        return controls;
    }

    private static List<CheckboxControl> FindSignedYesMatches(IEnumerable<CheckboxControl> controls)
    {
        List<CheckboxControl> exactMatches = SignedYesIdentifiers
            .SelectMany(identifier => FindExactMatches(controls, identifier))
            .Distinct()
            .ToList();

        if (exactMatches.Count > 0)
        {
            return exactMatches;
        }

        return SignedYesIdentifiers
            .SelectMany(identifier => FindContainsMatches(controls, identifier))
            .Distinct()
            .ToList();
    }

    private static List<CheckboxControl> FindExactMatches(IEnumerable<CheckboxControl> controls, string identifier)
    {
        return controls
            .Where(control =>
                MatchesExactIdentifier(control.Tag, identifier) ||
                MatchesExactIdentifier(control.Title, identifier))
            .ToList();
    }

    private static List<CheckboxControl> FindContainsMatches(IEnumerable<CheckboxControl> controls, string identifier)
    {
        return controls
            .Where(control =>
                MatchesContainsIdentifier(control.Tag, identifier) ||
                MatchesContainsIdentifier(control.Title, identifier))
            .ToList();
    }

    private static bool MatchesExactIdentifier(string? value, string identifier)
    {
        return !string.IsNullOrWhiteSpace(value) &&
               value.Equals(identifier, StringComparison.OrdinalIgnoreCase);
    }

    private static bool MatchesContainsIdentifier(string? value, string identifier)
    {
        return !string.IsNullOrWhiteSpace(value) &&
               value.Contains(identifier, StringComparison.OrdinalIgnoreCase);
    }

    private static bool? SummarizeState(IReadOnlyCollection<CheckboxControl> matches)
    {
        if (matches.Count == 0)
        {
            return null;
        }

        return matches.Any(static control => control.IsChecked);
    }

    private static bool? TryGetCheckboxState(SdtElement sdt)
    {
        foreach (OpenXmlElement element in sdt.Descendants<OpenXmlElement>())
        {
            if (!string.Equals(element.LocalName, "checked", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            OpenXmlAttribute valAttr = element.GetAttributes().FirstOrDefault(attribute =>
                string.Equals(attribute.LocalName, "val", StringComparison.OrdinalIgnoreCase));

            if (string.IsNullOrWhiteSpace(valAttr.Value))
            {
                continue;
            }

            if (valAttr.Value == "1" || valAttr.Value.Equals("true", StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            if (valAttr.Value == "0" || valAttr.Value.Equals("false", StringComparison.OrdinalIgnoreCase))
            {
                return false;
            }
        }

        return null;
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
        await response.WriteStringAsync(JsonSerializer.Serialize(payload, JsonOptions));
        return response;
    }
}
