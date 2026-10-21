import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../core/config/app_config.dart';
import 'update_installer.dart';

/// Updates a build installed from the `.deb`. Its bundle in `/opt` is owned by
/// root and tracked by dpkg, so it cannot be swapped like the tarball's: the
/// new package is installed through the package manager, as root via pkexec
/// (the desktop's password prompt), and the app is then started again.
class DebUpdateInstaller extends UpdateInstaller {
  const DebUpdateInstaller();

  /// The package `packaging/linux/build_deb.sh` builds.
  static const packageName = 'worknexus';

  /// Whether the running binary belongs to the installed [packageName]
  /// package, read from the file list dpkg keeps for it.
  static bool installedFromDeb({
    String dpkgInfo = '/var/lib/dpkg/info',
    String? executable,
  }) {
    final list = File('$dpkgInfo/$packageName.list');
    try {
      final exe = executable ?? Platform.resolvedExecutable;
      return list.existsSync() && list.readAsLinesSync().contains(exe);
    } on FileSystemException {
      return false;
    }
  }

  // $1 pid to wait for, $2 executable, $3 log file. A new process started
  // while this one still runs could find the old instance alive, so the
  // restart waits for it to exit.
  @visibleForTesting
  static const restartScript = r'''#!/bin/sh
exec >>"$3" 2>&1
set -x
while kill -0 "$1" 2>/dev/null; do sleep 0.3; done
nohup "$2" >/dev/null 2>&1 &
''';

  @override
  String get assetName => AppConfig.updateAssetDeb;

  /// The bundle folder holding the `WorkNexus` binary.
  @override
  String get installPath => File(Platform.resolvedExecutable).parent.path;

  /// The download is the package itself.
  @override
  Future<String> unpack(String zipPath, String directory) async => zipPath;

  /// The files are written by root, so what matters is that pkexec can raise
  /// the install to it, not whether this user can write to `/opt`.
  @override
  Future<bool> canReplace() async =>
      File('/usr/bin/pkexec').existsSync() && _packageTool != null;

  /// apt resolves dependencies a newer package may add; plain dpkg is the
  /// fallback where apt is missing.
  static List<String>? get _packageTool {
    if (File('/usr/bin/apt-get').existsSync()) {
      return const ['/usr/bin/apt-get', 'install', '-y'];
    }
    if (File('/usr/bin/dpkg').existsSync()) {
      return const ['/usr/bin/dpkg', '-i'];
    }
    return null;
  }

  /// Installs [stagedPath] before returning, so a cancelled password prompt
  /// or a failed install surfaces as an error while the app is still open.
  /// dpkg replaces files by renaming, so the running binary is unaffected
  /// until it exits.
  @override
  Future<void> launchSwap(
    String stagedPath, {
    required String scriptDir,
  }) async {
    final tool = _packageTool;
    if (tool == null) {
      throw const FileSystemException('No package manager to install with');
    }
    await runChecked('/usr/bin/pkexec', [...tool, stagedPath]);

    final file = File('$scriptDir/restart_after_update.sh');
    await file.writeAsString(restartScript);
    await Process.start('/bin/sh', [
      file.path,
      '$pid',
      Platform.resolvedExecutable,
      '$scriptDir/update.log',
    ], mode: ProcessStartMode.detached);
  }
}
