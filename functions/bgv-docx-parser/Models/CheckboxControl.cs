using System.Text.Json.Serialization;

namespace bgv_docx_parser.Models;

public sealed record CheckboxControl(
    [property: JsonPropertyName("tag")] string? Tag,
    [property: JsonPropertyName("title")] string? Title,
    [property: JsonPropertyName("isChecked")] bool IsChecked);
