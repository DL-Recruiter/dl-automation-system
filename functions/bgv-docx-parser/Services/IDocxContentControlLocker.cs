namespace bgv_docx_parser.Services;

public interface IDocxContentControlLocker
{
    (byte[] LockedDocxBytes, int LockedControlsCount) LockAll(byte[] docBytes);
}
