using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;

namespace bgv_docx_parser.Services;

public sealed class OpenXmlDocxContentControlLocker : IDocxContentControlLocker
{
    public (byte[] LockedDocxBytes, int LockedControlsCount) LockAll(byte[] docBytes)
    {
        using var stream = new MemoryStream();
        stream.Write(docBytes, 0, docBytes.Length);
        stream.Position = 0;

        using (WordprocessingDocument document = WordprocessingDocument.Open(stream, true))
        {
            IEnumerable<SdtElement> sdtNodes = document.MainDocumentPart?.Document?.Descendants<SdtElement>()
                ?? Enumerable.Empty<SdtElement>();

            int lockedCount = 0;

            foreach (SdtElement sdt in sdtNodes)
            {
                SdtProperties? properties = sdt.SdtProperties;
                if (properties is null)
                {
                    properties = new SdtProperties();
                    sdt.PrependChild(properties);
                }

                foreach (DocumentFormat.OpenXml.Wordprocessing.Lock existingLock in properties.Elements<DocumentFormat.OpenXml.Wordprocessing.Lock>().ToList())
                {
                    existingLock.Remove();
                }

                properties.AppendChild(new DocumentFormat.OpenXml.Wordprocessing.Lock
                {
                    Val = LockingValues.SdtContentLocked
                });

                lockedCount++;
            }

            document.MainDocumentPart?.Document?.Save();
            return (stream.ToArray(), lockedCount);
        }
    }
}
