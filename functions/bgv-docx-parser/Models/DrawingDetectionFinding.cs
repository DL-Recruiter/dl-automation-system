using System.Text.Json.Serialization;

namespace bgv_docx_parser.Models;

public sealed record DrawingDetectionFinding(
    [property: JsonPropertyName("kind")] string Kind,
    [property: JsonPropertyName("partUri")] string PartUri,
    [property: JsonPropertyName("detail")] string Detail);
