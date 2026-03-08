namespace bgv_docx_parser.Models;

public sealed record AuthorizationEvaluationResult(
    bool? SignedYes,
    bool? SignedNo,
    IReadOnlyCollection<CheckboxControl> SignedYesMatches,
    IReadOnlyCollection<CheckboxControl> SignedNoMatches);
