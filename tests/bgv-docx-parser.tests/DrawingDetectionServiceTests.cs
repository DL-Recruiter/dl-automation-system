using bgv_docx_parser.Models;
using bgv_docx_parser.Services;
using Xunit;

namespace bgv_docx_parser.tests;

public class DrawingDetectionServiceTests
{
    private readonly OpenXmlDrawingDetectionService _service = new();

    [Fact]
    public void No_Drawing_Content_Returns_LevelA_Enabled_With_No_Findings()
    {
        byte[] docBytes = DocxTestFactory.CreateDocument();

        DrawingDetectionResult result = _service.Detect(docBytes);

        Assert.True(result.Enabled);
        Assert.False(result.SignatureDetected);
        Assert.Equal("A", result.Level);
        Assert.Empty(result.Findings);
    }

    [Fact]
    public void Drawing_Canvas_Or_Group_Content_Returns_SignatureDetected_True()
    {
        byte[] docBytes = DocxTestFactory.CreateDocumentWithPackageXmlParts(
            new DocxTestFactory.PackageXmlPartDefinition(
                "<wpc:wpc xmlns:wpc=\"http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas\"><wpg:wgp xmlns:wpg=\"http://schemas.microsoft.com/office/word/2010/wordprocessingGroup\"><a:custGeom xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\"><a:pathLst><a:path w=\"100\" h=\"100\"><a:moveTo><a:pt x=\"0\" y=\"0\" /></a:moveTo><a:lnTo><a:pt x=\"100\" y=\"100\" /></a:lnTo></a:path></a:pathLst></a:custGeom></wpg:wgp></wpc:wpc>"));

        DrawingDetectionResult result = _service.Detect(docBytes);

        Assert.True(result.Enabled);
        Assert.True(result.SignatureDetected);
        Assert.Equal("A", result.Level);
        Assert.Contains(result.Findings, finding => finding.Kind == "canvasOrGroup");
        Assert.Contains(result.Findings, finding => finding.Kind == "freeform");
    }

    [Fact]
    public void Ink_Related_Content_Returns_SignatureDetected_True()
    {
        byte[] docBytes = DocxTestFactory.CreateDocumentWithPackageXmlParts(
            new DocxTestFactory.PackageXmlPartDefinition(
                "<inkml:ink xmlns:inkml=\"http://www.w3.org/2003/InkML\"><inkml:trace>0 0, 10 10</inkml:trace></inkml:ink>",
                UseInkContentType: true));

        DrawingDetectionResult result = _service.Detect(docBytes);

        Assert.True(result.Enabled);
        Assert.True(result.SignatureDetected);
        Assert.Equal("A", result.Level);
        Assert.Contains(result.Findings, finding => finding.Kind == "ink");
    }
}
