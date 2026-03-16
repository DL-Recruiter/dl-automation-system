using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Office2010.Word;
using DocumentFormat.OpenXml.Wordprocessing;

namespace bgv_docx_parser.tests;

internal static class DocxTestFactory
{
    public static byte[] CreateDocument(params CheckboxDefinition[] checkboxes)
    {
        return CreateDocument(checkboxes, Array.Empty<PackageXmlPartDefinition>());
    }

    public static byte[] CreateDocumentWithHeaderCheckbox(params CheckboxDefinition[] checkboxes)
    {
        using var stream = new MemoryStream();

        using (WordprocessingDocument document = WordprocessingDocument.Create(
                   stream,
                   DocumentFormat.OpenXml.WordprocessingDocumentType.Document,
                   true))
        {
            MainDocumentPart mainPart = document.AddMainDocumentPart();
            mainPart.Document = new Document(new Body(new Paragraph(new Run(new Text("BGV authorization test document")))));

            HeaderPart headerPart = mainPart.AddNewPart<HeaderPart>();
            string headerRelationshipId = mainPart.GetIdOfPart(headerPart);
            headerPart.Header = new Header();

            foreach (CheckboxDefinition checkbox in checkboxes)
            {
                headerPart.Header.AppendChild(CreateCheckboxParagraph(checkbox));
            }

            SectionProperties sectionProperties = mainPart.Document.Body!.GetFirstChild<SectionProperties>() ?? mainPart.Document.Body.AppendChild(new SectionProperties());
            sectionProperties.RemoveAllChildren<HeaderReference>();
            sectionProperties.AppendChild(new HeaderReference
            {
                Type = HeaderFooterValues.Default,
                Id = headerRelationshipId
            });

            headerPart.Header.Save();
            mainPart.Document.Save();
        }

        return stream.ToArray();
    }

    public static byte[] CreateDocumentWithPackageXmlParts(params PackageXmlPartDefinition[] packageXmlParts)
    {
        return CreateDocument(Array.Empty<CheckboxDefinition>(), packageXmlParts);
    }

    private static byte[] CreateDocument(
        IReadOnlyCollection<CheckboxDefinition> checkboxes,
        IReadOnlyCollection<PackageXmlPartDefinition> packageXmlParts)
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

            foreach (PackageXmlPartDefinition packageXmlPart in packageXmlParts)
            {
                AddPackageXmlPart(mainPart, packageXmlPart);
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

    private static void AddPackageXmlPart(MainDocumentPart mainPart, PackageXmlPartDefinition packageXmlPart)
    {
        CustomXmlPart customXmlPart = packageXmlPart.UseInkContentType
            ? mainPart.AddCustomXmlPart(CustomXmlPartType.InkContent)
            : mainPart.AddCustomXmlPart(CustomXmlPartType.CustomXml);

        using Stream stream = customXmlPart.GetStream(FileMode.Create, FileAccess.Write);
        using var writer = new StreamWriter(stream);
        writer.Write(packageXmlPart.XmlPayload);
    }

    internal sealed record CheckboxDefinition(
        string? Tag,
        string? Title,
        bool IsChecked,
        string DisplayText = "checkbox");

    internal sealed record PackageXmlPartDefinition(
        string XmlPayload,
        bool UseInkContentType = false);
}
