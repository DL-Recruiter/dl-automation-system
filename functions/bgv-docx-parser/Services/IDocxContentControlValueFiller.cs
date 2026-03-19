namespace bgv_docx_parser.Services;

public interface IDocxContentControlValueFiller
{
    (byte[] FilledDocxBytes, int FilledControlsCount) Fill(
        byte[] docBytes,
        IReadOnlyDictionary<string, string> replacements);
}
