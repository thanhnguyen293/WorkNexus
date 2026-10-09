import 'dart:async';
import 'dart:io';

import '../../../../core/config/app_config.dart';
import 'update_installer.dart';

/// Copies the new build over the app folder. Windows keeps a running exe and
/// its DLLs locked, so the copy waits for this process to exit and robocopy
/// retries while the locks clear.
class WindowsUpdateInstaller extends UpdateInstaller {
  const WindowsUpdateInstaller();

  static const _script =
      r'''param([int]$ProcId, [string]$Source, [string]$Target, [string]$Exe, [string]$Log)
Start-Transcript -Path $Log -Append | Out-Null
try { Wait-Process -Id $ProcId -Timeout 120 -ErrorAction Stop } catch {}
robocopy $Source $Target /E /R:30 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
Start-Process -FilePath $Exe
''';

  @override
  String get assetName => AppConfig.updateAssetWindows;

  /// The folder holding `WorkNexus.exe`, its DLLs and `data/`.
  @override
  String get installPath => File(Platform.resolvedExecutable).parent.path;

  /// robocopy writes into the app folder itself, not beside it.
  @override
  Directory get writableDirectory => Directory(installPath);

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
    // Not `ProcessStartMode.detached`: PowerShell started without a console
    // never ran the script (the app quit and nothing was installed). A normal
    // child outlives this process all the same.
    final helper = await Process.start('powershell.exe', [
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
      '-Log',
      '$scriptDir\\update.log',
    ]);
    unawaited(helper.stdin.close().catchError((_) {}));
    unawaited(helper.stdout.drain<void>());
    unawaited(helper.stderr.drain<void>());
  }
}
