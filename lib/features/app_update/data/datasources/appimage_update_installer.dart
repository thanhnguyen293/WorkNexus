import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../core/config/app_config.dart';
import 'update_installer.dart';

/// Replaces the `.AppImage` file the app was started from. The download is
/// the whole build, so there is nothing to unpack: the new image is renamed
/// over the old one once the app has exited.
class AppImageUpdateInstaller extends UpdateInstaller {
  const AppImageUpdateInstaller(this.appImage);

  /// The running `.AppImage` file (its `APPIMAGE` variable).
  final String appImage;

  // $1 pid to wait for, $2 installed image, $3 new image, $4 log file. The
  // staged image sits in the temp dir, often another filesystem, so it is
  // copied beside the install first: the swap itself is then one rename, and
  // a failed copy leaves the old image untouched.
  @visibleForTesting
  static const script = r'''#!/bin/sh
exec >>"$4" 2>&1
set -x
while kill -0 "$1" 2>/dev/null; do sleep 0.3; done
new="$2.new"
rm -f "$new"
if cp "$3" "$new" && chmod +x "$new"; then
  mv -f "$new" "$2"
fi
rm -f "$new"
nohup "$2" >/dev/null 2>&1 &
''';

  @override
  String get assetName => AppConfig.updateAssetAppImage;

  @override
  String get installPath => appImage;

  @override
  Future<String> unpack(String zipPath, String directory) async => zipPath;

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
      '$scriptDir/update.log',
    ], mode: ProcessStartMode.detached);
  }
}
