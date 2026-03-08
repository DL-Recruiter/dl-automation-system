using System.Text.Json.Serialization;

namespace bgv_docx_parser.Models;

public sealed record DrawingDetectionResult(
    [property: JsonPropertyName("enabled")] bool Enabled,
    [property: JsonPropertyName("signatureDetected")] bool? SignatureDetected,
    [property: JsonPropertyName("level")] string? Level,
    [property: JsonPropertyName("findings")] IReadOnlyCollection<DrawingDetectionFinding> Findings)
{
    public static DrawingDetectionResult Disabled { get; } =
        new(false, null, null, Array.Empty<DrawingDetectionFinding>());
}
