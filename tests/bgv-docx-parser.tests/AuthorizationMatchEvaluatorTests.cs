using bgv_docx_parser.Models;
using bgv_docx_parser.Services;
using Xunit;

namespace bgv_docx_parser.tests;

public class AuthorizationMatchEvaluatorTests
{
    private readonly AuthorizationMatchEvaluator _evaluator = new();

    [Fact]
    public void Evaluate_Uses_Exact_SignedYes_Match()
    {
        CheckboxControl[] controls =
        [
            new CheckboxControl("SignedYes", null, true)
        ];

        AuthorizationEvaluationResult result = _evaluator.Evaluate(controls);

        Assert.True(result.SignedYes);
        Assert.Null(result.SignedNo);
        Assert.Single(result.SignedYesMatches);
    }

    [Fact]
    public void Evaluate_Uses_CandidateAuthorisation_As_Compatibility_Alias()
    {
        CheckboxControl[] controls =
        [
            new CheckboxControl("CandidateAuthorisation", null, true)
        ];

        AuthorizationEvaluationResult result = _evaluator.Evaluate(controls);

        Assert.True(result.SignedYes);
        Assert.Single(result.SignedYesMatches);
    }

    [Fact]
    public void Evaluate_Falls_Back_To_Substring_Matching_When_No_Exact_Match_Exists()
    {
        CheckboxControl[] controls =
        [
            new CheckboxControl("LegacySignedYesCheckbox", null, true)
        ];

        AuthorizationEvaluationResult result = _evaluator.Evaluate(controls);

        Assert.True(result.SignedYes);
        Assert.Single(result.SignedYesMatches);
    }

    [Fact]
    public void Evaluate_Uses_Any_Checked_Semantics_For_Duplicate_SignedYes_Matches()
    {
        CheckboxControl[] controls =
        [
            new CheckboxControl("SignedYes", null, false),
            new CheckboxControl(null, "SignedYes", true)
        ];

        AuthorizationEvaluationResult result = _evaluator.Evaluate(controls);

        Assert.True(result.SignedYes);
        Assert.Equal(2, result.SignedYesMatches.Count);
    }

    [Fact]
    public void Evaluate_Uses_Exact_Match_Only_For_SignedNo()
    {
        CheckboxControl[] controls =
        [
            new CheckboxControl("SignedNo", null, false),
            new CheckboxControl("LegacySignedNoCheckbox", null, true)
        ];

        AuthorizationEvaluationResult result = _evaluator.Evaluate(controls);

        Assert.False(result.SignedNo);
        Assert.Single(result.SignedNoMatches);
    }

    [Fact]
    public void Evaluate_Returns_Null_When_No_Matches_Are_Found()
    {
        CheckboxControl[] controls =
        [
            new CheckboxControl("OtherCheckbox", null, true)
        ];

        AuthorizationEvaluationResult result = _evaluator.Evaluate(controls);

        Assert.Null(result.SignedYes);
        Assert.Null(result.SignedNo);
        Assert.Empty(result.SignedYesMatches);
        Assert.Empty(result.SignedNoMatches);
    }
}
