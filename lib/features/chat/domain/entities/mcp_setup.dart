import 'package:freezed_annotation/freezed_annotation.dart';

part 'mcp_setup.freezed.dart';

/// What an AI tool needs to run the bundled MCP server: the script, copied
/// out of the app to a fixed place, and the Node.js that runs it.
@freezed
abstract class McpSetup with _$McpSetup {
  const McpSetup._();

  const factory McpSetup({
    required String scriptPath,

    /// Absolute path of the `node` found on this computer; null when none.
    String? nodePath,

    /// Its `node --version` (`v22.13.0`); null when none was found.
    String? nodeVersion,
  }) = _McpSetup;

  /// The oldest Node.js the server runs on (it uses the built-in
  /// `node:sqlite`).
  static const minNode = (major: 22, minor: 13);

  /// Whether [nodeVersion] is [minNode] or newer.
  bool get nodeSupported => supports(nodeVersion);

  /// Whether [nodePath] belongs to one version of a Node.js version manager
  /// (nvm, fnm, asdf, mise, nodenv, nvm-windows): switching or removing that version
  /// breaks the registered command, so the guide says to register it again.
  bool get nodeFromVersionManager {
    final path = nodePath?.replaceAll(r'\', '/').toLowerCase();
    if (path == null) return false;
    return _versionManagerDirs.any(path.contains) ||
        RegExp(r'/nvm/v\d').hasMatch(path);
  }

  static const _versionManagerDirs = [
    '/.nvm/versions/',
    'fnm_multishells',
    '/fnm/node-versions/',
    '/.asdf/installs/',
    '/mise/installs/',
    '/.nodenv/versions/',
  ];

  /// Whether Node.js [version] (`v22.13.0`) is [minNode] or newer.
  static bool supports(String? version) {
    final match = RegExp(r'^v?(\d+)\.(\d+)').firstMatch(version ?? '');
    if (match == null) return false;
    final major = int.parse(match[1] ?? '0');
    final minor = int.parse(match[2] ?? '0');
    return major > minNode.major ||
        (major == minNode.major && minor >= minNode.minor);
  }
}
