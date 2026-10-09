import 'dart:io';

import '../../../../core/config/app_config.dart';
import 'update_installer.dart';

/// Swaps `WorkNexus.app` in place. The bundle is moved aside first, so a
/// failed move puts the old one back rather than leaving no app at all.
class MacosUpdateInstaller extends UpdateInstaller {
  const MacosUpdateInstaller();

  // $1 pid to wait for, $2 installed .app, $3 new .app.
  static const _script = r'''#!/bin/sh
while kill -0 "$1" 2>/dev/null; do sleep 0.3; done
backup="$2.previous"
rm -rf "$backup"
if mv "$2" "$backup"; then
  if mv "$3" "$2"; then
    rm -rf "$backup"
  else
    mv "$backup" "$2"
  fi
fi
open "$2"
''';

  @override
  String get assetName => AppConfig.updateAssetMacos;

  /// `…/WorkNexus.app/Contents/MacOS/WorkNexus` → `…/WorkNexus.app`.
  @override
  String get installPath =>
      File(Platform.resolvedExecutable).parent.parent.parent.path;

  @override
  Future<bool> canReplace() async =>
      installPath.endsWith('.app') && await super.canReplace();

  @override
  Future<String> unpack(String zipPath, String directory) async {
    // ditto keeps the bundle's symlinks and signature intact; unzip does not.
    await runChecked('/usr/bin/ditto', ['-x', '-k', zipPath, directory]);
    final app = Directory(
      directory,
    ).listSync().whereType<Directory>().where((d) => d.path.endsWith('.app'));
    if (app.isEmpty) {
      throw const FileSystemException('The update holds no .app bundle');
    }
    return app.first.path;
  }

  @override
  Future<void> launchSwap(
    String stagedPath, {
    required String scriptDir,
  }) async {
    final script = File('$scriptDir/install_update.sh');
    await script.writeAsString(_script);
    await Process.start('/bin/sh', [
      script.path,
      '$pid',
      installPath,
      stagedPath,
    ], mode: ProcessStartMode.detached);
  }
}
