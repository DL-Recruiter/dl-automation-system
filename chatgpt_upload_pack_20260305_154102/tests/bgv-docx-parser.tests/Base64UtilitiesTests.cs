using bgv_docx_parser.Utilities;
using Xunit;

namespace bgv_docx_parser.tests;

public class Base64UtilitiesTests
{
    [Fact]
    public void Normalize_Trims_Whitespace()
    {
        string? normalized = Base64Utilities.Normalize("  QUJD  ");

        Assert.Equal("QUJD", normalized);
    }

    [Fact]
    public void Normalize_Returns_Null_For_Empty_Input()
    {
        string? normalized = Base64Utilities.Normalize("   ");

        Assert.Null(normalized);
    }

    [Fact]
    public void TryEstimateDecodedLength_Returns_Length_For_Valid_Base64()
    {
        bool success = Base64Utilities.TryEstimateDecodedLength("QUJD", out int decodedLength);

        Assert.True(success);
        Assert.Equal(3, decodedLength);
    }

    [Fact]
    public void TryEstimateDecodedLength_Fails_For_Invalid_Length()
    {
        bool success = Base64Utilities.TryEstimateDecodedLength("ABC", out _);

        Assert.False(success);
    }
}
