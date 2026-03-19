using System.Text.Json;

namespace bgv_docx_parser.Services;

public sealed class ReportSummaryValueMapper : IReportSummaryValueMapper
{
    private static readonly IReadOnlyDictionary<string, string> Form1TagToKey =
        new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["Form1.CandidateFullName"] = "rfe96c622120343f294de908deb0e849d",
            ["Form1.CandidateEmail"] = "rcd8057cd92b24b5594681a5b39c07e3d",
            ["Form1.IdentificationNumberNRIC"] = "rd2fba2b09afd478ba21df420406c9b49",
            ["Form1.IdentificationNumberPassport"] = "rf5b324c022804863a720ef13edeb9d9b"
        };

    private static readonly IReadOnlyDictionary<string, string> Form2TagToKey =
        new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["Form2.Q4"] = "rd745d133eb7f4611b59ea051f980f97a",
            ["Form2.Q5"] = "rccaf3632669648baaa335c12d4ea40bf",
            ["Form2.Q6"] = "rcf35c7cc008e472f9d0b84bde67cc1ff",
            ["Form2.Q7"] = "r19aae6e8163d4aaeb8a3f3f2d5329be2",
            ["Form2.Q8"] = "r2d39255c2449439096683ca0e39241b0",
            ["Form2.Q9"] = "rd05170e51ac34fef95f5464cf348bedc",
            ["Form2.Q10"] = "ra03058e9bbfd40d28014b0c669e92434",
            ["Form2.Q11"] = "r0bef44c0d22d493f95a33484875b951e",
            ["Form2.Q12"] = "r513ad5ab3a14453286bdb910820985ec",
            ["Form2.Q13"] = "ra6ab2e26d2d84a92b33148fc4694773a",
            ["Form2.Q14"] = "r49ca8a655f5e4bcba0e8f75d4475ad77",
            ["Form2.Q15"] = "r9594fab1bfa04c90883b1dffd7f4549e",
            ["Form2.Q16"] = "r72b23e4aa192405091846e1279085029",
            ["Form2.Q17"] = "r9a95095b3d7d4d9f8bc985025614bd79",
            ["Form2.Q18"] = "r83027392ccb043e2a637b06ff4b54ac8",
            ["Form2.Q19"] = "r4061a9d19aae45d9915d2f508a5c3ea9",
            ["Form2.Q20"] = "ra15c799c557d42d1bcee1de947c29466",
            ["Form2.Q21"] = "r7bd26b4a7e94430dbda54f9e8b8212e4",
            ["Form2.Q22"] = "rc50b684c30314c5d991ff39a0d3d0dd1",
            ["Form2.Q23"] = "r96d079f9858e40bab89ab0ea4ad23931",
            ["Form2.Q24"] = "r35197d5910d2489db0d5786157b35295",
            ["Form2.Q25"] = "rafe3ada4157c49fb9e555cd0fb53bd59",
            ["Form2.Q26"] = "r5f7ebc3390bc4699b160504c65254c3e",
            ["Form2.Q27"] = "rab9c2a586db943b18ac02367d3b1d3f7",
            ["Form2.Q28"] = "r1f2d7ec255b1430fbb2a6e56ce4042d1",
            ["Form2.Q29"] = "r7b65617c391a48239b9f75dd239702c3",
            ["Form2.Q30"] = "reb80c95cd24242998cbc884c24254bed",
            ["Form2.Q31"] = "r57e4baaeaafc4ffc8b3977149b18f2f2"
        };

    public IReadOnlyDictionary<string, string> BuildMappings(
        string? form1RawJson,
        string? form2RawJson,
        IReadOnlyDictionary<string, string?>? form1FallbackValues = null)
    {
        IReadOnlyDictionary<string, string> form1Values = ParseFlatStringMap(form1RawJson);
        IReadOnlyDictionary<string, string> form2Values = ParseFlatStringMap(form2RawJson);

        var replacements = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        foreach ((string tag, string key) in Form1TagToKey)
        {
            string value = GetNormalizedFormValue(form1Values, key);
            if (string.IsNullOrWhiteSpace(value) &&
                form1FallbackValues is not null &&
                form1FallbackValues.TryGetValue(tag, out string? fallbackValue) &&
                !string.IsNullOrWhiteSpace(fallbackValue))
            {
                value = fallbackValue.Trim();
            }

            if (tag.Equals("Form1.IdentificationNumberNRIC", StringComparison.OrdinalIgnoreCase))
            {
                replacements[tag] = string.IsNullOrWhiteSpace(value) ? "N/A" : value;
            }
            else if (tag.Equals("Form1.IdentificationNumberPassport", StringComparison.OrdinalIgnoreCase))
            {
                replacements[tag] = string.IsNullOrWhiteSpace(value) ? "N/A" : value;
            }
            else
            {
                replacements[tag] = value;
            }
        }

        foreach ((string tag, string key) in Form2TagToKey)
        {
            replacements[tag] = GetNormalizedFormValue(form2Values, key);
        }

        replacements["Form2.Q31FileName"] = GetUploadFileNames(form2Values);

        return replacements;
    }

    private static IReadOnlyDictionary<string, string> ParseFlatStringMap(string? rawJson)
    {
        if (string.IsNullOrWhiteSpace(rawJson))
        {
            return new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        }

        try
        {
            using JsonDocument document = JsonDocument.Parse(rawJson);
            if (document.RootElement.ValueKind != JsonValueKind.Object)
            {
                return new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            }

            var values = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (JsonProperty property in document.RootElement.EnumerateObject())
            {
                values[property.Name] = property.Value.ValueKind switch
                {
                    JsonValueKind.String => property.Value.GetString() ?? string.Empty,
                    JsonValueKind.Null => string.Empty,
                    _ => property.Value.ToString()
                };
            }

            return values;
        }
        catch (JsonException)
        {
            return new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        }
    }

    private static string GetNormalizedFormValue(IReadOnlyDictionary<string, string> values, string key)
    {
        if (!values.TryGetValue(key, out string? value) || string.IsNullOrWhiteSpace(value))
        {
            return string.Empty;
        }

        return NormalizeValue(value);
    }

    private static string NormalizeValue(string value)
    {
        string trimmed = value.Trim();
        if (!LooksLikeJson(trimmed))
        {
            return trimmed;
        }

        try
        {
            using JsonDocument document = JsonDocument.Parse(trimmed);
            return document.RootElement.ValueKind switch
            {
                JsonValueKind.Array => NormalizeJsonArray(document.RootElement),
                JsonValueKind.Object => NormalizeJsonObject(document.RootElement),
                _ => trimmed
            };
        }
        catch (JsonException)
        {
            return trimmed;
        }
    }

    private static bool LooksLikeJson(string value) =>
        value.StartsWith("[", StringComparison.Ordinal) ||
        value.StartsWith("{", StringComparison.Ordinal);

    private static string NormalizeJsonArray(JsonElement array)
    {
        List<string> values = new();

        foreach (JsonElement item in array.EnumerateArray())
        {
            switch (item.ValueKind)
            {
                case JsonValueKind.String:
                    values.Add(item.GetString() ?? string.Empty);
                    break;
                case JsonValueKind.Object:
                    values.Add(NormalizeJsonObject(item));
                    break;
                default:
                    values.Add(item.ToString());
                    break;
            }
        }

        return string.Join(", ", values.Where(static value => !string.IsNullOrWhiteSpace(value)));
    }

    private static string NormalizeJsonObject(JsonElement item)
    {
        foreach (string propertyName in new[] { "name", "fileName", "displayName", "link" })
        {
            if (item.TryGetProperty(propertyName, out JsonElement property) && property.ValueKind == JsonValueKind.String)
            {
                return property.GetString() ?? string.Empty;
            }
        }

        return item.ToString();
    }

    private static string GetUploadFileNames(IReadOnlyDictionary<string, string> values)
    {
        foreach (string value in values.Values)
        {
            if (string.IsNullOrWhiteSpace(value) || !LooksLikeJson(value.Trim()))
            {
                continue;
            }

            try
            {
                using JsonDocument document = JsonDocument.Parse(value);
                if (document.RootElement.ValueKind != JsonValueKind.Array)
                {
                    continue;
                }

                List<string> fileNames = document.RootElement
                    .EnumerateArray()
                    .Where(static item => item.ValueKind == JsonValueKind.Object)
                    .Select(NormalizeJsonObject)
                    .Where(static name => !string.IsNullOrWhiteSpace(name))
                    .ToList();

                if (fileNames.Count > 0)
                {
                    return string.Join(", ", fileNames);
                }
            }
            catch (JsonException)
            {
                // Ignore non-upload JSON-like strings and continue scanning.
            }
        }

        return "No file uploaded";
    }
}
