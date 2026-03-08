using bgv_docx_parser.Models;

namespace bgv_docx_parser.Services;

public interface IDrawingDetectionService
{
    DrawingDetectionResult Detect(byte[] docBytes);
}
