using System.Text.Json;

namespace bgv_docx_parser.Utilities;

public static class FunctionJson
{
    public static JsonSerializerOptions Options { get; } = new()
    {
        PropertyNameCaseInsensitive = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };
}
