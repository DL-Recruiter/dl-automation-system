namespace bgv_docx_parser.Services;

public interface IReportSummaryValueMapper
{
    IReadOnlyDictionary<string, string> BuildMappings(
        string? form1RawJson,
        string? form2RawJson,
        IReadOnlyDictionary<string, string?>? form1FallbackValues = null);
}
