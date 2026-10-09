import 'dart:io';

import 'update_installer.dart';

/// Copies the new build over the app folder. Windows keeps a running exe and
/// its DLLs locked, so the copy waits for this process to exit and robocopy
/// retries while the locks clear.
class WindowsUpdateInstaller extends UpdateInstaller {
  const WindowsUpdateInstaller();

  static const _script =
      r'''param([int]$ProcId, [string]$Source, [string]$Target, [string]$Exe)
try { Wait-Process -Id $ProcId -Timeout 120 -ErrorAction Stop } catch {}
robocopy $Source $Target /E /R:30 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
Start-Process -FilePath $Exe
''';

  @override
  String get assetName => 'worknexus-windows.zip';

  /// The folder holding `WorkNexus.exe`, its DLLs and `data/`.
  @override
  String get installPath => File(Platform.resolvedExecutable).parent.path;

  @override
  Future<String> unpack(String zipPath, String directory) async {
    // tar (bsdtar) ships with Windows 10+ and reads zip archives.
    await runChecked('tar', ['-xf', zipPath, '-C', directory]);
    final exe = Platform.resolvedExecutable.split(r'\').last;
    if (!File('$directory\\$exe').existsSync()) {
      throw FileSystemException('The update holds no $exe', directory);
    }
    return directory;
  }

  @override
  Future<void> launchSwap(
    String stagedPath, {
    required String scriptDir,
  }) async {
    final script = File('$scriptDir\\install_update.ps1');
    await script.writeAsString(_script);
    await Process.start('powershell.exe', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-WindowStyle',
      'Hidden',
      '-File',
      script.path,
      '-ProcId',
      '$pid',
      '-Source',
      stagedPath,
      '-Target',
      installPath,
      '-Exe',
      Platform.resolvedExecutable,
    ], mode: ProcessStartMode.detached);
  }
}
