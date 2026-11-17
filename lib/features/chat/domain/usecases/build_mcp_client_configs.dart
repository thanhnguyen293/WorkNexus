import 'dart:convert';

import '../entities/mcp_setup.dart';
import '../value_objects/mcp_client_config.dart';

/// The ways to register the bundled MCP server with AI tools on [McpHostOs]:
/// the Claude Code command, the Claude Desktop config entry (macOS and
/// Windows only — there is no Linux build), and the same entry for any other
/// MCP client. Both use absolute paths: a GUI-launched tool does not get the
/// user's shell `PATH`, so a bare `node` may not be found.
class BuildMcpClientConfigs {
  const BuildMcpClientConfigs();

  /// The name the server is registered under.
  static const serverName = 'worknexus';

  List<McpClientConfig> call(McpSetup setup, McpHostOs os) {
    final node = setup.nodePath ?? 'node';
    final entry = const JsonEncoder.withIndent('  ').convert({
      'mcpServers': {
        serverName: {
          'command': node,
          'args': [setup.scriptPath],
        },
      },
    });
    final desktopFile = switch (os) {
      McpHostOs.macos =>
        '~/Library/Application Support/Claude/claude_desktop_config.json',
      McpHostOs.windows => r'%APPDATA%\Claude\claude_desktop_config.json',
      McpHostOs.linux => null,
    };
    return [
      (
        client: McpClient.claudeCode,
        configFile: null,
        snippet:
            'claude mcp add $serverName -s user -- '
            '"$node" "${setup.scriptPath}"',
      ),
      if (desktopFile != null)
        (
          client: McpClient.claudeDesktop,
          configFile: desktopFile,
          snippet: entry,
        ),
      (client: McpClient.other, configFile: null, snippet: entry),
    ];
  }
}
