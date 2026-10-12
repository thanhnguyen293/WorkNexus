import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../core/config/app_config.dart';
import 'update_installer.dart';

/// Swaps the bundle folder (binary + `lib/` + `data/`) in place.
class LinuxUpdateInstaller extends UpdateInstaller {
  const LinuxUpdateInstaller();

  // $1 pid to wait for, $2 installed bundle, $3 new bundle, $4 executable,
  // $5 log file. The staged bundle sits in the temp dir, often another
  // filesystem, so it is copied beside the install first: the swap itself is
  // then two renames, and a failed copy leaves the old bundle untouched.
  @visibleForTesting
  static const script = r'''#!/bin/sh
exec >>"$5" 2>&1
set -x
while kill -0 "$1" 2>/dev/null; do sleep 0.3; done
new="$2.new"
backup="$2.previous"
rm -rf "$new" "$backup"
if cp -a "$3" "$new" && mv "$2" "$backup"; then
  if mv "$new" "$2"; then
    rm -rf "$backup"
  else
    mv "$backup" "$2"
  fi
fi
rm -rf "$new"
nohup "$4" >/dev/null 2>&1 &
''';

  @override
  String get assetName => AppConfig.updateAssetLinux;

  /// The bundle folder holding the `WorkNexus` binary.
  @override
  String get installPath => File(Platform.resolvedExecutable).parent.path;

  @override
  Future<String> unpack(String zipPath, String directory) async {
    // tar keeps the binary's executable bit, which a zip would lose.
    await runChecked('tar', ['-xzf', zipPath, '-C', directory]);
    final exe = Platform.resolvedExecutable.split('/').last;
    if (!File('$directory/$exe').existsSync()) {
      throw FileSystemException('The update holds no $exe', directory);
    }
    return directory;
  }

  @override
  Future<void> launchSwap(
    String stagedPath, {
    required String scriptDir,
  }) async {
    final file = File('$scriptDir/install_update.sh');
    await file.writeAsString(script);
    await Process.start('/bin/sh', [
      file.path,
      '$pid',
      installPath,
      stagedPath,
      Platform.resolvedExecutable,
      '$scriptDir/update.log',
    ], mode: ProcessStartMode.detached);
  }
}
