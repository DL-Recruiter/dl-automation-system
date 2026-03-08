using bgv_docx_parser.Models;

namespace bgv_docx_parser.Services;

public sealed class AuthorizationMatchEvaluator : IAuthorizationMatchEvaluator
{
    private static readonly string[] SignedYesIdentifiers =
    [
        "SignedYes",
        "CandidateAuthorisation"
    ];

    public AuthorizationEvaluationResult Evaluate(IReadOnlyCollection<CheckboxControl> controls)
    {
        List<CheckboxControl> signedYesMatches = FindSignedYesMatches(controls);
        List<CheckboxControl> signedNoMatches = FindExactMatches(controls, "SignedNo");

        return new AuthorizationEvaluationResult(
            SummarizeState(signedYesMatches),
            SummarizeState(signedNoMatches),
            signedYesMatches,
            signedNoMatches);
    }

    private static List<CheckboxControl> FindSignedYesMatches(IEnumerable<CheckboxControl> controls)
    {
        List<CheckboxControl> exactMatches = SignedYesIdentifiers
            .SelectMany(identifier => FindExactMatches(controls, identifier))
            .Distinct()
            .ToList();

        if (exactMatches.Count > 0)
        {
            return exactMatches;
        }

        return SignedYesIdentifiers
            .SelectMany(identifier => FindContainsMatches(controls, identifier))
            .Distinct()
            .ToList();
    }

    private static List<CheckboxControl> FindExactMatches(IEnumerable<CheckboxControl> controls, string identifier)
    {
        return controls
            .Where(control =>
                MatchesExactIdentifier(control.Tag, identifier) ||
                MatchesExactIdentifier(control.Title, identifier))
            .ToList();
    }

    private static List<CheckboxControl> FindContainsMatches(IEnumerable<CheckboxControl> controls, string identifier)
    {
        return controls
            .Where(control =>
                MatchesContainsIdentifier(control.Tag, identifier) ||
                MatchesContainsIdentifier(control.Title, identifier))
            .ToList();
    }

    private static bool MatchesExactIdentifier(string? value, string identifier)
    {
        return !string.IsNullOrWhiteSpace(value) &&
               value.Equals(identifier, StringComparison.OrdinalIgnoreCase);
    }

    private static bool MatchesContainsIdentifier(string? value, string identifier)
    {
        return !string.IsNullOrWhiteSpace(value) &&
               value.Contains(identifier, StringComparison.OrdinalIgnoreCase);
    }

    private static bool? SummarizeState(IReadOnlyCollection<CheckboxControl> matches)
    {
        if (matches.Count == 0)
        {
            return null;
        }

        return matches.Any(static control => control.IsChecked);
    }
}
