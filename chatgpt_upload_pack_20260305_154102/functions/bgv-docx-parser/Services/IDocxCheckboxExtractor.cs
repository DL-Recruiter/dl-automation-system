using bgv_docx_parser.Models;

namespace bgv_docx_parser.Services;

public interface IDocxCheckboxExtractor
{
    IReadOnlyCollection<CheckboxControl> Extract(byte[] docBytes);
}
