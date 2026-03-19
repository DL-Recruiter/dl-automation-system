using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;
using DocumentFormat.OpenXml;

namespace bgv_docx_parser.Services;

public sealed class OpenXmlDocxContentControlValueFiller : IDocxContentControlValueFiller
{
    public (byte[] FilledDocxBytes, int FilledControlsCount) Fill(
        byte[] docBytes,
        IReadOnlyDictionary<string, string> replacements)
    {
        using var stream = new MemoryStream();
        stream.Write(docBytes, 0, docBytes.Length);
        stream.Position = 0;
        int filledCount;

        using (WordprocessingDocument document = WordprocessingDocument.Open(stream, true))
        {
            IEnumerable<SdtElement> sdtNodes = EnumerateAllContentControls(document);
            filledCount = 0;

            foreach (SdtElement sdt in sdtNodes)
            {
                string? tag = sdt.SdtProperties?.GetFirstChild<Tag>()?.Val?.Value;
                string? alias = sdt.SdtProperties?.GetFirstChild<SdtAlias>()?.Val?.Value;

                string? replacement = ResolveReplacement(replacements, tag, alias);
                if (replacement is null)
                {
                    continue;
                }

                ApplyValue(sdt, replacement);
                filledCount++;
            }

            document.MainDocumentPart?.Document?.Save();
        }

        return (stream.ToArray(), filledCount);
    }

    private static IEnumerable<SdtElement> EnumerateAllContentControls(WordprocessingDocument document)
    {
        IEnumerable<SdtElement> main = document.MainDocumentPart?.Document?.Descendants<SdtElement>()
            ?? Enumerable.Empty<SdtElement>();
        IEnumerable<SdtElement> headers = document.MainDocumentPart?.HeaderParts
            .Where(static part => part.Header is not null)
            .SelectMany(static part => part.Header!.Descendants<SdtElement>())
            ?? Enumerable.Empty<SdtElement>();
        IEnumerable<SdtElement> footers = document.MainDocumentPart?.FooterParts
            .Where(static part => part.Footer is not null)
            .SelectMany(static part => part.Footer!.Descendants<SdtElement>())
            ?? Enumerable.Empty<SdtElement>();

        return main.Concat(headers).Concat(footers);
    }

    private static string? ResolveReplacement(
        IReadOnlyDictionary<string, string> replacements,
        string? tag,
        string? alias)
    {
        if (!string.IsNullOrWhiteSpace(tag) && replacements.TryGetValue(tag, out string? byTag))
        {
            return byTag;
        }

        if (!string.IsNullOrWhiteSpace(alias) && replacements.TryGetValue(alias, out string? byAlias))
        {
            return byAlias;
        }

        return null;
    }

    private static void ApplyValue(SdtElement sdt, string replacement)
    {
        List<Text> texts = sdt.Descendants<Text>().ToList();
        if (texts.Count > 0)
        {
            texts[0].Text = replacement;
            texts[0].Space = SpaceProcessingModeValues.Preserve;

            foreach (Text extra in texts.Skip(1))
            {
                extra.Text = string.Empty;
                extra.Space = SpaceProcessingModeValues.Preserve;
            }

            return;
        }

        switch (sdt)
        {
            case SdtRun sdtRun:
                EnsureRunContent(sdtRun, replacement);
                break;
            case SdtBlock sdtBlock:
                EnsureBlockContent(sdtBlock, replacement);
                break;
            case SdtCell sdtCell:
                EnsureCellContent(sdtCell, replacement);
                break;
        }
    }

    private static void EnsureRunContent(SdtRun sdtRun, string replacement)
    {
        SdtContentRun contentRun = sdtRun.GetFirstChild<SdtContentRun>() ?? sdtRun.AppendChild(new SdtContentRun());
        contentRun.RemoveAllChildren();
        contentRun.AppendChild(new Run(new Text(replacement)
        {
            Space = SpaceProcessingModeValues.Preserve
        }));
    }

    private static void EnsureBlockContent(SdtBlock sdtBlock, string replacement)
    {
        SdtContentBlock contentBlock = sdtBlock.GetFirstChild<SdtContentBlock>() ?? sdtBlock.AppendChild(new SdtContentBlock());
        contentBlock.RemoveAllChildren();
        contentBlock.AppendChild(new Paragraph(new Run(new Text(replacement)
        {
            Space = SpaceProcessingModeValues.Preserve
        })));
    }

    private static void EnsureCellContent(SdtCell sdtCell, string replacement)
    {
        SdtContentCell contentCell = sdtCell.GetFirstChild<SdtContentCell>() ?? sdtCell.AppendChild(new SdtContentCell());
        contentCell.RemoveAllChildren();
        contentCell.AppendChild(new TableCell(new Paragraph(new Run(new Text(replacement)
        {
            Space = SpaceProcessingModeValues.Preserve
        }))));
    }
}
