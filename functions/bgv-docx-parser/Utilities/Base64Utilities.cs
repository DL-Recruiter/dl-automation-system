namespace bgv_docx_parser.Utilities;

public static class Base64Utilities
{
    public static string? Normalize(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    }

    public static bool TryEstimateDecodedLength(string base64, out int decodedLength)
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
}
