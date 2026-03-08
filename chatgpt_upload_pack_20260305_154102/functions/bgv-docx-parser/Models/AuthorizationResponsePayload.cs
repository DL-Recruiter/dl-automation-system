using System.Text.Json.Serialization;

namespace bgv_docx_parser.Models;

public sealed record AuthorizationResponsePayload(
    [property: JsonPropertyName("fileName")] string? FileName,
    [property: JsonPropertyName("signedYes")] bool? SignedYes,
    [property: JsonPropertyName("signedNo")] bool? SignedNo,
    [property: JsonPropertyName("controlsFound")] IReadOnlyCollection<CheckboxControl> ControlsFound,
    [property: JsonPropertyName("note")] string Note,
    [property: JsonPropertyName("drawingDetection")] DrawingDetectionResult DrawingDetection);
