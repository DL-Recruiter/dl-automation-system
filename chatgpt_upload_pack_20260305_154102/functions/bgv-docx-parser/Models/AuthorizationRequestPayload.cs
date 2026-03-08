using System.Text.Json.Serialization;

namespace bgv_docx_parser.Models;

public sealed record AuthorizationRequestPayload(
    [property: JsonPropertyName("fileName")] string? FileName,
    [property: JsonPropertyName("docxBase64")] string? DocxBase64);
