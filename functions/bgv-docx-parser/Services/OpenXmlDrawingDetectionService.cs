using System.Xml;
using System.Xml.Linq;
using bgv_docx_parser.Models;
using DocumentFormat.OpenXml.Packaging;

namespace bgv_docx_parser.Services;

public sealed class OpenXmlDrawingDetectionService : IDrawingDetectionService
{
    private static readonly string[] InkNamespaceTokens =
    [
        "ink",
        "InkML"
    ];

    private static readonly string[] CanvasOrGroupNamespaceTokens =
    [
        "wordprocessingCanvas",
        "wordprocessingGroup"
    ];

    private static readonly string[] DrawingNamespaceTokens =
    [
        "drawingml",
        "schemas.openxmlformats.org/drawingml",
        "schemas.microsoft.com/office/word"
    ];

    private static readonly HashSet<string> InkLocalNames = new(StringComparer.OrdinalIgnoreCase)
    {
        "ink",
        "trace",
        "traceGroup",
        "inkSource"
    };

    private static readonly HashSet<string> CanvasOrGroupLocalNames = new(StringComparer.OrdinalIgnoreCase)
    {
        "wpc",
        "wgp",
        "grpSp",
        "grpSpPr"
    };

    private static readonly HashSet<string> FreeformGeometryLocalNames = new(StringComparer.OrdinalIgnoreCase)
    {
        "custGeom",
        "pathLst",
        "path",
        "moveTo",
        "lnTo",
        "arcTo",
        "cubicBezTo",
        "quadBezTo"
    };

    public DrawingDetectionResult Detect(byte[] docBytes)
    {
        using var stream = new MemoryStream(docBytes);
        using var document = WordprocessingDocument.Open(stream, false);

        var findings = new List<DrawingDetectionFinding>();
        var findingKeys = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (OpenXmlPart part in EnumerateParts(document))
        {
            InspectPart(part, findings, findingKeys);
        }

        return new DrawingDetectionResult(
            true,
            findings.Count > 0,
            "A",
            findings);
    }

    private static IEnumerable<OpenXmlPart> EnumerateParts(OpenXmlPartContainer container)
    {
        var visited = new HashSet<Uri>();
        var stack = new Stack<OpenXmlPartContainer>();
        stack.Push(container);

        while (stack.Count > 0)
        {
            OpenXmlPartContainer current = stack.Pop();

            foreach (IdPartPair idPartPair in current.Parts)
            {
                OpenXmlPart part = idPartPair.OpenXmlPart;

                if (!visited.Add(part.Uri))
                {
                    continue;
                }

                yield return part;
                stack.Push(part);
            }
        }
    }

    private static void InspectPart(
        OpenXmlPart part,
        ICollection<DrawingDetectionFinding> findings,
        ISet<string> findingKeys)
    {
        string partUri = part.Uri.ToString();

        if (ContainsInkToken(part.ContentType) || ContainsInkToken(partUri))
        {
            AddFinding(findings, findingKeys, "ink", partUri, "Ink-related package markers detected.");
        }

        XDocument? xmlDocument = TryLoadXml(part);
        if (xmlDocument?.Root is null)
        {
            return;
        }

        if (ContainsInkElements(xmlDocument.Root))
        {
            AddFinding(findings, findingKeys, "ink", partUri, "Ink-related XML detected.");
        }

        if (ContainsCanvasOrGroupElements(xmlDocument.Root))
        {
            AddFinding(findings, findingKeys, "canvasOrGroup", partUri, "Drawing canvas or grouped drawing XML detected.");
        }

        if (ContainsFreeformGeometry(xmlDocument.Root))
        {
            AddFinding(findings, findingKeys, "freeform", partUri, "Freeform drawing geometry detected.");
        }
    }

    private static XDocument? TryLoadXml(OpenXmlPart part)
    {
        if (!IsXmlPart(part))
        {
            return null;
        }

        try
        {
            using Stream stream = part.GetStream(FileMode.Open, FileAccess.Read);
            using XmlReader reader = XmlReader.Create(
                stream,
                new XmlReaderSettings
                {
                    DtdProcessing = DtdProcessing.Prohibit,
                    IgnoreComments = true,
                    IgnoreWhitespace = true
                });

            return XDocument.Load(reader, LoadOptions.None);
        }
        catch (InvalidDataException)
        {
            return null;
        }
        catch (XmlException)
        {
            return null;
        }
    }

    private static bool IsXmlPart(OpenXmlPart part)
    {
        return part.ContentType.Contains("xml", StringComparison.OrdinalIgnoreCase) ||
               part.Uri.ToString().EndsWith(".xml", StringComparison.OrdinalIgnoreCase) ||
               part.Uri.ToString().EndsWith(".rels", StringComparison.OrdinalIgnoreCase);
    }

    private static bool ContainsInkElements(XElement root)
    {
        return root
            .DescendantsAndSelf()
            .Any(static element =>
                InkLocalNames.Contains(element.Name.LocalName) ||
                ContainsAnyToken(element.Name.NamespaceName, InkNamespaceTokens));
    }

    private static bool ContainsCanvasOrGroupElements(XElement root)
    {
        return root
            .DescendantsAndSelf()
            .Any(static element =>
                CanvasOrGroupLocalNames.Contains(element.Name.LocalName) ||
                ContainsAnyToken(element.Name.NamespaceName, CanvasOrGroupNamespaceTokens));
    }

    private static bool ContainsFreeformGeometry(XElement root)
    {
        foreach (XElement element in root.DescendantsAndSelf())
        {
            if (!FreeformGeometryLocalNames.Contains(element.Name.LocalName))
            {
                continue;
            }

            if (IsDrawingContext(element))
            {
                return true;
            }
        }

        return false;
    }

    private static bool IsDrawingContext(XElement element)
    {
        for (XElement? current = element; current is not null; current = current.Parent)
        {
            if (ContainsAnyToken(current.Name.NamespaceName, DrawingNamespaceTokens))
            {
                return true;
            }
        }

        return false;
    }

    private static bool ContainsInkToken(string value)
    {
        return ContainsAnyToken(value, InkNamespaceTokens);
    }

    private static bool ContainsAnyToken(string? value, IEnumerable<string> tokens)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return false;
        }

        return tokens.Any(token => value.Contains(token, StringComparison.OrdinalIgnoreCase));
    }

    private static void AddFinding(
        ICollection<DrawingDetectionFinding> findings,
        ISet<string> findingKeys,
        string kind,
        string partUri,
        string detail)
    {
        string key = $"{kind}|{partUri}";
        if (!findingKeys.Add(key))
        {
            return;
        }

        findings.Add(new DrawingDetectionFinding(kind, partUri, detail));
    }
}
