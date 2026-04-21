using System.Text.Json;
using bgv_docx_parser.Services;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;
using Xunit;

namespace bgv_docx_parser.tests;

public class ReportSummaryFillerTests
{
    private readonly ReportSummaryValueMapper _mapper = new();
    private readonly OpenXmlDocxContentControlValueFiller _filler = new();

    [Fact]
    public void Mapper_Builds_Live_Template_Replacements_And_Detects_Upload_File_Name()
    {
        string form1RawJson = JsonSerializer.Serialize(new Dictionary<string, string?>
        {
            ["rfe96c622120343f294de908deb0e849d"] = "Test Candidate",
            ["rcd8057cd92b24b5594681a5b39c07e3d"] = "candidate@example.com",
            ["rd2fba2b09afd478ba21df420406c9b49"] = "S1234567A",
            ["rf5b324c022804863a720ef13edeb9d9b"] = string.Empty
        });

        string form2RawJson = JsonSerializer.Serialize(new Dictionary<string, string?>
        {
            ["rd745d133eb7f4611b59ea051f980f97a"] = "REQ-BGV-20260319-abcde-EMP1",
            ["rccaf3632669648baaa335c12d4ea40bf"] = "Test Company",
            ["rcf35c7cc008e472f9d0b84bde67cc1ff"] = "201912345Z",
            ["r19aae6e8163d4aaeb8a3f3f2d5329be2"] = "123 Test Street",
            ["rd05170e51ac34fef95f5464cf348bedc"] = "[\"Company UEN\"]",
            ["r57e4baaeaafc4ffc8b3977149b18f2f2"] = "Yes",
            ["uploadField"] = "[{\"name\":\"stamp.png\",\"link\":\"https://example.invalid/stamp.png\"}]"
        });

        IReadOnlyDictionary<string, string> mappings = _mapper.BuildMappings(form1RawJson, form2RawJson);

        Assert.Equal("Test Candidate", mappings["Form1.CandidateFullName"]);
        Assert.Equal("candidate@example.com", mappings["Form1.CandidateEmail"]);
        Assert.Equal("S1234567A", mappings["Form1.IdentificationNumberNRIC"]);
        Assert.Equal("N/A", mappings["Form1.IdentificationNumberPassport"]);
        Assert.Equal("REQ-BGV-20260319-abcde-EMP1", mappings["Form2.Q4"]);
        Assert.Equal("Test Company", mappings["Form2.Q5"]);
        Assert.Equal("Yes", mappings["Form2.Q31"]);
        Assert.Equal("stamp.png", mappings["Form2.Q31FileName"]);
    }

    [Fact]
    public void Mapper_Uses_Form1Fallback_When_Form1RawJson_Is_Missing()
    {
        string form2RawJson = JsonSerializer.Serialize(new Dictionary<string, string?>
        {
            ["rd745d133eb7f4611b59ea051f980f97a"] = "REQ-BGV-20260319-abcde-EMP1"
        });

        IReadOnlyDictionary<string, string> mappings = _mapper.BuildMappings(
            null,
            form2RawJson,
            new Dictionary<string, string?>
            {
                ["Form1.CandidateFullName"] = "Fallback Candidate",
                ["Form1.CandidateEmail"] = "fallback@example.com",
                ["Form1.IdentificationNumberNRIC"] = "S7654321A",
                ["Form1.IdentificationNumberPassport"] = null
            });

        Assert.Equal("Fallback Candidate", mappings["Form1.CandidateFullName"]);
        Assert.Equal("fallback@example.com", mappings["Form1.CandidateEmail"]);
        Assert.Equal("S7654321A", mappings["Form1.IdentificationNumberNRIC"]);
        Assert.Equal("N/A", mappings["Form1.IdentificationNumberPassport"]);
    }

    [Fact]
    public void Mapper_Prefers_Form1Fallback_When_Raw_Form1_Contains_Stale_Candidate_Values()
    {
        string form1RawJson = JsonSerializer.Serialize(new Dictionary<string, string?>
        {
            ["rfe96c622120343f294de908deb0e849d"] = "Wrong Candidate Name",
            ["rcd8057cd92b24b5594681a5b39c07e3d"] = "wrong@example.com",
            ["rd2fba2b09afd478ba21df420406c9b49"] = "S1111111A"
        });

        IReadOnlyDictionary<string, string> mappings = _mapper.BuildMappings(
            form1RawJson,
            null,
            new Dictionary<string, string?>
            {
                ["Form1.CandidateFullName"] = "Leon",
                ["Form1.CandidateEmail"] = "leon@example.com",
                ["Form1.IdentificationNumberNRIC"] = "S2222222B",
                ["Form1.IdentificationNumberPassport"] = null
            });

        Assert.Equal("Leon", mappings["Form1.CandidateFullName"]);
        Assert.Equal("leon@example.com", mappings["Form1.CandidateEmail"]);
        Assert.Equal("S2222222B", mappings["Form1.IdentificationNumberNRIC"]);
        Assert.Equal("N/A", mappings["Form1.IdentificationNumberPassport"]);
    }

    [Fact]
    public void Mapper_Uses_General_Inaccuracy_Details_As_Fallback_For_Selected_Employment_Issues()
    {
        string form2RawJson = JsonSerializer.Serialize(new Dictionary<string, string?>
        {
            ["r72b23e4aa192405091846e1279085029"] = "[\"Employment Period\",\"Last Position Held\"]",
            ["ra03058e9bbfd40d28014b0c669e92434"] = "Employer noted declared dates and title do not match payroll records.",
            ["r9a95095b3d7d4d9f8bc985025614bd79"] = string.Empty,
            ["r83027392ccb043e2a637b06ff4b54ac8"] = string.Empty
        });

        IReadOnlyDictionary<string, string> mappings = _mapper.BuildMappings(null, form2RawJson);

        Assert.Equal(
            "Employer noted declared dates and title do not match payroll records.",
            mappings["Form2.Q17"]);
        Assert.Equal(
            "Employer noted declared dates and title do not match payroll records.",
            mappings["Form2.Q18"]);
    }

    [Fact]
    public void Mapper_Supports_Current_Live_Form2_WriteIn_Question_Keys()
    {
        string form2RawJson = JsonSerializer.Serialize(new Dictionary<string, string?>
        {
            ["rb0aafb54344e4a3aa982d1d934bea772"] = "Employment period mismatch",
            ["r2f96ac1d76c5452d89ddf71d8e62d34d"] = "Job title mismatch",
            ["r049d77f872984fdb9b67110db534a792"] = "Salary mismatch",
            ["r0dbb99e26abc4bcd90544e9ac3bd924e"] = "Other abnormality noted"
        });

        IReadOnlyDictionary<string, string> mappings = _mapper.BuildMappings(null, form2RawJson);

        Assert.Equal("Employment period mismatch", mappings["Form2.Q17"]);
        Assert.Equal("Job title mismatch", mappings["Form2.Q18"]);
        Assert.Equal("Salary mismatch", mappings["Form2.Q19"]);
        Assert.Equal("Other abnormality noted", mappings["Form2.Q20"]);
    }

    [Fact]
    public void Filler_Replaces_Content_Control_Text_By_Tag()
    {
        byte[] template = CreateTextControlDocument(new Dictionary<string, string>
        {
            ["Form1.CandidateFullName"] = "Click or tap here to enter text.",
            ["Form2.Q4"] = "Click or tap here to enter text."
        });

        (byte[] filledDocxBytes, int filledCount) = _filler.Fill(
            template,
            new Dictionary<string, string>
            {
                ["Form1.CandidateFullName"] = "Test Candidate",
                ["Form2.Q4"] = "REQ-BGV-20260319-abcde-EMP1"
            });

        Assert.Equal(2, filledCount);

        string documentText = ExtractDocumentText(filledDocxBytes);
        Assert.Contains("Test Candidate", documentText);
        Assert.Contains("REQ-BGV-20260319-abcde-EMP1", documentText);
        Assert.DoesNotContain("Click or tap here to enter text.", documentText);
    }

    private static byte[] CreateTextControlDocument(IReadOnlyDictionary<string, string> tags)
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
            foreach ((string tag, string placeholder) in tags)
            {
                body.AppendChild(
                    new Paragraph(
                        new SdtRun(
                            new SdtProperties(
                                new Tag { Val = tag },
                                new SdtAlias { Val = tag }),
                            new SdtContentRun(
                                new Run(new Text(placeholder))))));
            }

            mainPart.Document.Save();
        }

        return stream.ToArray();
    }

    private static string ExtractDocumentText(byte[] docBytes)
    {
        using var stream = new MemoryStream(docBytes);
        using WordprocessingDocument document = WordprocessingDocument.Open(stream, false);
        IEnumerable<string> texts = document.MainDocumentPart?.Document?.Descendants<Text>()
            .Select(static text => text.Text)
            ?? Enumerable.Empty<string>();
        return string.Join(" ", texts);
    }
}
