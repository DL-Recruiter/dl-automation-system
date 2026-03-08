namespace bgv_docx_parser.Utilities;

public static class RequestBodyReader
{
    public static async Task<byte[]> ReadAsync(Stream stream, int maxBytes)
    {
        using var output = new MemoryStream();
        byte[] buffer = new byte[81920];
        int totalBytes = 0;

        while (true)
        {
            int read = await stream.ReadAsync(buffer.AsMemory(0, buffer.Length));
            if (read == 0)
            {
                break;
            }

            totalBytes += read;
            if (totalBytes > maxBytes)
            {
                throw new InvalidDataException("Request body too large.");
            }

            output.Write(buffer, 0, read);
        }

        return output.ToArray();
    }
}
