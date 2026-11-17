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
  bool get nodeSupported {
    final match = RegExp(r'^v?(\d+)\.(\d+)').firstMatch(nodeVersion ?? '');
    if (match == null) return false;
    final major = int.parse(match[1] ?? '0');
    final minor = int.parse(match[2] ?? '0');
    return major > minNode.major ||
        (major == minNode.major && minor >= minNode.minor);
  }
}
