import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Copies the MCP server the app bundles as an asset to a fixed file AI tools
/// can be pointed at. The asset itself lives inside the app (and, for an
/// AppImage, under a mount that changes every launch), so it cannot be
/// registered directly.
class McpScriptInstaller {
  const McpScriptInstaller({required this.bundle, required this.directory});

  final AssetBundle bundle;

  /// Where the copy goes (`<app support>/mcp`).
  final Future<Directory> Function() directory;

  static const asset = 'assets/mcp/worknexus-mcp.mjs';
  static const fileName = 'worknexus-mcp.mjs';

  /// The installed script's path. Rewrites it only when this build bundles a
  /// different version, so a tool running it is not disturbed for nothing.
  Future<String> install() async => _write(await _file());

  /// Brings a copy installed earlier up to this build's version, so AI tools
  /// registered before an app update run the new server; null (and nothing
  /// written) when the user never set one up.
  Future<String?> refresh() async {
    final file = await _file();
    return await file.exists() ? _write(file) : null;
  }

  Future<File> _file() async => File('${(await directory()).path}/$fileName');

  Future<String> _write(File file) async {
    final data = await bundle.load(asset);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    await file.parent.create(recursive: true);
    if (await file.exists() && listEquals(await file.readAsBytes(), bytes)) {
      return file.path;
    }
    final temp = File('${file.path}.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(file.path);
    return file.path;
  }
}
