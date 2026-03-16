using bgv_docx_parser.Models;
using bgv_docx_parser.Services;
using Xunit;

namespace bgv_docx_parser.tests;

public class ParserIntegrationTests
{
    private readonly OpenXmlDocxCheckboxExtractor _extractor = new();
    private readonly AuthorizationMatchEvaluator _evaluator = new();

    [Fact]
    public void SignedYes_Document_Returns_SignedYes_True_And_SignedNo_False()
    {
        byte[] docBytes = DocxTestFactory.CreateDocument(
            new DocxTestFactory.CheckboxDefinition("SignedYes", "SignedYes", true),
            new DocxTestFactory.CheckboxDefinition("SignedNo", "SignedNo", false));

        (IReadOnlyCollection<CheckboxControl> controlsFound, AuthorizationEvaluationResult evaluation) = Parse(docBytes);

        Assert.True(evaluation.SignedYes);
        Assert.False(evaluation.SignedNo);
        Assert.Equal(2, controlsFound.Count);
    }

    [Fact]
    public void SignedNo_Document_Returns_SignedYes_False_And_SignedNo_True()
    {
        byte[] docBytes = DocxTestFactory.CreateDocument(
            new DocxTestFactory.CheckboxDefinition("SignedYes", "SignedYes", false),
            new DocxTestFactory.CheckboxDefinition("SignedNo", "SignedNo", true));

        (_, AuthorizationEvaluationResult evaluation) = Parse(docBytes);

        Assert.False(evaluation.SignedYes);
        Assert.True(evaluation.SignedNo);
    }

    [Fact]
    public void Unchecked_Document_Matches_Current_Semantics()
    {
        byte[] docBytes = DocxTestFactory.CreateDocument(
            new DocxTestFactory.CheckboxDefinition("SignedYes", "SignedYes", false),
            new DocxTestFactory.CheckboxDefinition("SignedNo", "SignedNo", false));

        (_, AuthorizationEvaluationResult evaluation) = Parse(docBytes);

        Assert.False(evaluation.SignedYes);
        Assert.False(evaluation.SignedNo);
    }

    [Fact]
    public void Multiple_SignedYes_Controls_Return_SignedYes_True()
    {
        byte[] docBytes = DocxTestFactory.CreateDocument(
            new DocxTestFactory.CheckboxDefinition("SignedYes", "SignedYes", false),
            new DocxTestFactory.CheckboxDefinition(null, "SignedYes", true));

        (_, AuthorizationEvaluationResult evaluation) = Parse(docBytes);

        Assert.True(evaluation.SignedYes);
        Assert.Equal(2, evaluation.SignedYesMatches.Count);
    }

    [Fact]
    public void No_Checkbox_Document_Matches_Current_Semantics_And_ControlsFound_Is_Empty()
    {
        byte[] docBytes = DocxTestFactory.CreateDocument();

        (IReadOnlyCollection<CheckboxControl> controlsFound, AuthorizationEvaluationResult evaluation) = Parse(docBytes);

        Assert.Null(evaluation.SignedYes);
        Assert.Null(evaluation.SignedNo);
        Assert.Empty(controlsFound);
    }

    [Fact]
    public void Header_Checkbox_Is_Extracted_And_Evaluated()
    {
        byte[] docBytes = DocxTestFactory.CreateDocumentWithHeaderCheckbox(
            new DocxTestFactory.CheckboxDefinition("SignedYes", "SignedYes", true));

        (IReadOnlyCollection<CheckboxControl> controlsFound, AuthorizationEvaluationResult evaluation) = Parse(docBytes);

        Assert.Single(controlsFound);
        Assert.True(evaluation.SignedYes);
    }

    private (IReadOnlyCollection<CheckboxControl> ControlsFound, AuthorizationEvaluationResult Evaluation) Parse(byte[] docBytes)
    {
        IReadOnlyCollection<CheckboxControl> controlsFound = _extractor.Extract(docBytes);
        AuthorizationEvaluationResult evaluation = _evaluator.Evaluate(controlsFound);
        return (controlsFound, evaluation);
    }
}
