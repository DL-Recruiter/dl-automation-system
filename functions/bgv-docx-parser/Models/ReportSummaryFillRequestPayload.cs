using System.Text.Json.Serialization;

namespace bgv_docx_parser.Models;

public sealed record ReportSummaryFillRequestPayload(
    [property: JsonPropertyName("fileName")] string? FileName,
    [property: JsonPropertyName("docxBase64")] string? DocxBase64,
    [property: JsonPropertyName("form1RawJson")] string? Form1RawJson,
    [property: JsonPropertyName("form2RawJson")] string? Form2RawJson);
