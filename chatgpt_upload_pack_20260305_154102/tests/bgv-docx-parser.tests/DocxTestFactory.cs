using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Office2010.Word;
using DocumentFormat.OpenXml.Wordprocessing;

namespace bgv_docx_parser.tests;

internal static class DocxTestFactory
{
    public static byte[] CreateDocument(params CheckboxDefinition[] checkboxes)
    {
        using var stream = new MemoryStream();

        using (WordprocessingDocument document = WordprocessingDocument.Create(
                   stream,
                   DocumentFormat.OpenXml.WordprocessingDocumentType.Document,
                   true))
        {
            MainDocumentPart mainPart = document.AddMainDocumentPart();
            mainPart.Document = new Document(new Body());

            Body body = mainPart.Document.Body!;
            body.AppendChild(new Paragraph(new Run(new Text("BGV authorization test document"))));

            foreach (CheckboxDefinition checkbox in checkboxes)
            {
                body.AppendChild(CreateCheckboxParagraph(checkbox));
            }

            mainPart.Document.Save();
        }

        return stream.ToArray();
    }

    private static Paragraph CreateCheckboxParagraph(CheckboxDefinition checkbox)
    {
        var properties = new SdtProperties();

        if (checkbox.Tag is not null)
        {
            properties.Append(new Tag { Val = checkbox.Tag });
        }

        if (checkbox.Title is not null)
        {
            properties.Append(new SdtAlias { Val = checkbox.Title });
        }

        properties.Append(CreateCheckboxDefinitionElement(checkbox.IsChecked));

        return new Paragraph(
            new SdtRun(
                properties,
                new SdtContentRun(
                    new Run(new Text(checkbox.DisplayText)))));
    }

    private static SdtContentCheckBox CreateCheckboxDefinitionElement(bool isChecked)
    {
        string checkedValue = isChecked ? "1" : "0";
        return new SdtContentCheckBox(
            $"<w14:checkbox xmlns:w14=\"http://schemas.microsoft.com/office/word/2010/wordml\"><w14:checked w14:val=\"{checkedValue}\" /></w14:checkbox>");
    }

    internal sealed record CheckboxDefinition(
        string? Tag,
        string? Title,
        bool IsChecked,
        string DisplayText = "checkbox");
}
