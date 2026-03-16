using System.Text.Json.Serialization;

namespace bgv_docx_parser.Models;

public sealed record LockContentControlsResponsePayload(
    [property: JsonPropertyName("fileName")] string? FileName,
    [property: JsonPropertyName("lockedControlsCount")] int LockedControlsCount,
    [property: JsonPropertyName("lockedDocxBase64")] string LockedDocxBase64,
    [property: JsonPropertyName("note")] string Note);
