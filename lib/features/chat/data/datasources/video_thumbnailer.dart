import 'dart:io';
import 'dart:typed_data';

/// Extracts a still frame from a local video for chat previews, using what
/// the OS already has: QuickLook (`qlmanage`) on macOS, the Shell thumbnail
/// API (what Explorer shows, via PowerShell) on Windows, else `ffmpeg` when it
/// is on PATH. Returns null when none works; the UI then shows an icon. The
/// PNG is cached next to the video.
class VideoThumbnailer {
  const VideoThumbnailer();

  static const _width = 480;

  /// The frame made earlier for [videoPath], even if the video itself is
  /// gone from the cache; null when there is none.
  Future<Uint8List?> cachedThumbnailOf(String videoPath) async {
    final cached = File('$videoPath.thumb.png');
    try {
      if (!await cached.exists()) return null;
      // Mark as used so the cache keeps the frame.
      await cached.setLastModified(DateTime.now());
      return await cached.readAsBytes();
    } on FileSystemException {
      return null;
    }
  }

  Future<Uint8List?> thumbnailOf(String videoPath) async {
    final cached = File('$videoPath.thumb.png');
    if (await cached.exists()) return cached.readAsBytes();
    final made = switch (Platform.operatingSystem) {
      'macos' => await _quickLook(videoPath, cached),
      'windows' =>
        await _windowsShell(videoPath, cached) ||
            await _ffmpeg(videoPath, cached),
      _ => await _ffmpeg(videoPath, cached),
    };
    return made ? cached.readAsBytes() : null;
  }

  Future<bool> _quickLook(String videoPath, File target) async {
    final outDir = await Directory('${target.parent.path}/.thumbs')
        .create(recursive: true);
    try {
      final run = await Process.run('qlmanage', [
        '-t',
        '-s',
        '$_width',
        '-o',
        outDir.path,
        videoPath,
      ]).timeout(const Duration(seconds: 20));
      final produced = File(
        '${outDir.path}/${videoPath.split(Platform.pathSeparator).last}.png',
      );
      if (run.exitCode != 0 || !await produced.exists()) return false;
      await produced.rename(target.path);
      return true;
    } on Exception {
      return false;
    }
  }

  /// Asks the Windows Shell for the video's thumbnail (Media Foundation
  /// decodes it, so it covers what Explorer can preview). THUMBNAILONLY keeps
  /// a generic file icon from being returned as a "thumbnail".
  Future<bool> _windowsShell(String videoPath, File target) async {
    String quote(String s) => "'${s.replaceAll("'", "''")}'";
    final script =
        '''
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System; using System.Runtime.InteropServices;
using System.Drawing; using System.Drawing.Imaging;
[ComImport, Guid("bcc18b79-ba16-442f-80c4-8a59c30c463b"),
 InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IShellItemImageFactory {
  [PreserveSig] int GetImage(WnSize size, int flags, out IntPtr bitmap);
}
[StructLayout(LayoutKind.Sequential)]
public struct WnSize { public int cx; public int cy; }
public static class WnThumb {
  [DllImport("shell32.dll", CharSet = CharSet.Unicode, PreserveSig = false)]
  static extern void SHCreateItemFromParsingName(string path, IntPtr ctx,
    [MarshalAs(UnmanagedType.LPStruct)] Guid riid,
    [MarshalAs(UnmanagedType.Interface)] out IShellItemImageFactory item);
  [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr handle);
  public static void Save(string src, string dst, int width) {
    IShellItemImageFactory item;
    SHCreateItemFromParsingName(src, IntPtr.Zero,
      typeof(IShellItemImageFactory).GUID, out item);
    IntPtr bitmap;
    if (item.GetImage(new WnSize { cx = width, cy = width }, 0x8, out bitmap) != 0)
      throw new Exception("no thumbnail");
    try { using (var image = Image.FromHbitmap(bitmap)) image.Save(dst, ImageFormat.Png); }
    finally { DeleteObject(bitmap); }
  }
}
"@
[WnThumb]::Save(${quote(videoPath)}, ${quote(target.path)}, $_width)
''';
    try {
      final run = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        script,
      ]).timeout(const Duration(seconds: 30));
      return run.exitCode == 0 && await target.exists();
    } on Exception {
      return false;
    }
  }

  Future<bool> _ffmpeg(String videoPath, File target) async {
    try {
      final run = await Process.run('ffmpeg', [
        '-y',
        '-loglevel',
        'error',
        '-ss',
        '0.5',
        '-i',
        videoPath,
        '-frames:v',
        '1',
        '-vf',
        'scale=$_width:-1',
        target.path,
      ]).timeout(const Duration(seconds: 20));
      return run.exitCode == 0 && await target.exists();
    } on Exception {
      return false;
    }
  }
}
