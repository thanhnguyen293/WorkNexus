import 'dart:convert';
import 'dart:io';

/// Raw access to OpenCode's credential file (`auth.json`) — the file
/// `opencode auth login` writes. Infrastructure detail, confined to `data/`
/// (CLAUDE.md rule 3.4).
class OpenCodeAuthFile {
  const OpenCodeAuthFile({this._pathOverride});

  /// Explicit file path, for tests and unusual installs. Null ⇒ [_candidates].
  final String? _pathOverride;

  static const _fileName = 'auth.json';

  /// The file OpenCode is actually using: the first candidate that exists, else
  /// the preferred location so a first save creates it where the CLI looks.
  File resolve() {
    final override = _pathOverride?.trim();
    if (override != null && override.isNotEmpty) return File(override);
    final candidates = _candidates();
    for (final path in candidates) {
      if (File(path).existsSync()) return File(path);
    }
    return File(candidates.first);
  }

  /// Where OpenCode keeps its data dir, in the order it resolves them:
  /// `$XDG_DATA_HOME`, then `~/.local/share` (used on macOS/Linux and by the
  /// npm install on Windows), then `%LOCALAPPDATA%`.
  List<String> _candidates() {
    final env = Platform.environment;
    final sep = Platform.pathSeparator;
    final home =
        (Platform.isWindows ? env['USERPROFILE'] : env['HOME']) ??
        Directory.current.path;
    final xdg = env['XDG_DATA_HOME'];
    final localAppData = env['LOCALAPPDATA'];
    return [
      if (xdg != null && xdg.isNotEmpty) '$xdg${sep}opencode$sep$_fileName',
      '$home$sep.local${sep}share${sep}opencode$sep$_fileName',
      if (localAppData != null && localAppData.isNotEmpty)
        '$localAppData${sep}opencode$sep$_fileName',
    ];
  }

  /// Every entry keyed by provider id. A missing or empty file reads as `{}` so
  /// a first save is an ordinary write rather than a special case.
  Future<Map<String, dynamic>> read() async {
    final file = resolve();
    if (!file.existsSync()) return <String, dynamic>{};
    final raw = (await file.readAsString()).trim();
    if (raw.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  /// Replaces the file's contents with [entries].
  ///
  /// Written to a sibling temp file and renamed, so an interrupted write can't
  /// truncate the credentials OpenCode depends on, and chmod'd to `0600` because
  /// the file holds secrets (matching what the CLI itself does).
  Future<void> write(Map<String, dynamic> entries) async {
    final file = resolve();
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.worknexus.tmp');
    await temp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(entries),
      flush: true,
    );
    await _restrictPermissions(temp);
    await temp.rename(file.path);
  }

  Future<void> _restrictPermissions(File file) async {
    if (Platform.isWindows) return;
    await Process.run('chmod', ['600', file.path]);
  }
}
