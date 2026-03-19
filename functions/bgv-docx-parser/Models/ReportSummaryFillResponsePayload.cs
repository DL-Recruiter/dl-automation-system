using System.Text.Json.Serialization;

namespace bgv_docx_parser.Models;

public sealed record ReportSummaryFillResponsePayload(
    [property: JsonPropertyName("fileName")] string? FileName,
    [property: JsonPropertyName("filledControlsCount")] int FilledControlsCount,
    [property: JsonPropertyName("filledDocxBase64")] string FilledDocxBase64,
    [property: JsonPropertyName("mappedTags")] IReadOnlyCollection<string> MappedTags,
    [property: JsonPropertyName("note")] string Note);
