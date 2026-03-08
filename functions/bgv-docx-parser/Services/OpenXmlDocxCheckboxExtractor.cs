using bgv_docx_parser.Models;
using DocumentFormat.OpenXml;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;

namespace bgv_docx_parser.Services;

public sealed class OpenXmlDocxCheckboxExtractor : IDocxCheckboxExtractor
{
    public IReadOnlyCollection<CheckboxControl> Extract(byte[] docBytes)
    {
        using var stream = new MemoryStream(docBytes);
        using var doc = WordprocessingDocument.Open(stream, false);

        IEnumerable<SdtElement> sdtNodes = doc.MainDocumentPart?.Document?.Descendants<SdtElement>()
            ?? Enumerable.Empty<SdtElement>();

        var controls = new List<CheckboxControl>();

        foreach (SdtElement sdt in sdtNodes)
        {
            bool? isChecked = TryGetCheckboxState(sdt);
            if (isChecked is null)
            {
                continue;
            }

            string? tag = sdt.SdtProperties?.GetFirstChild<Tag>()?.Val?.Value;
            string? title = sdt.SdtProperties?.GetFirstChild<SdtAlias>()?.Val?.Value;
            controls.Add(new CheckboxControl(tag, title, isChecked.Value));
        }

        return controls;
    }

    private static bool? TryGetCheckboxState(SdtElement sdt)
    {
        foreach (OpenXmlElement element in sdt.Descendants<OpenXmlElement>())
        {
            if (!string.Equals(element.LocalName, "checked", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            OpenXmlAttribute valAttr = element.GetAttributes().FirstOrDefault(attribute =>
                string.Equals(attribute.LocalName, "val", StringComparison.OrdinalIgnoreCase));

            if (string.IsNullOrWhiteSpace(valAttr.Value))
            {
                continue;
            }

            if (valAttr.Value == "1" || valAttr.Value.Equals("true", StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            if (valAttr.Value == "0" || valAttr.Value.Equals("false", StringComparison.OrdinalIgnoreCase))
            {
                return false;
            }
        }

        return null;
    }
}
