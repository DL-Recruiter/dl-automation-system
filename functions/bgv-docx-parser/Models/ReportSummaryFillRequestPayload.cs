using System.Text.Json.Serialization;

namespace bgv_docx_parser.Models;

public sealed record ReportSummaryFillRequestPayload(
    [property: JsonPropertyName("fileName")] string? FileName,
    [property: JsonPropertyName("docxBase64")] string? DocxBase64,
    [property: JsonPropertyName("form1RawJson")] string? Form1RawJson,
    [property: JsonPropertyName("form2RawJson")] string? Form2RawJson,
    [property: JsonPropertyName("form1CandidateFullName")] string? Form1CandidateFullName,
    [property: JsonPropertyName("form1CandidateEmail")] string? Form1CandidateEmail,
    [property: JsonPropertyName("form1IdentificationNumberNRIC")] string? Form1IdentificationNumberNRIC,
    [property: JsonPropertyName("form1IdentificationNumberPassport")] string? Form1IdentificationNumberPassport);
