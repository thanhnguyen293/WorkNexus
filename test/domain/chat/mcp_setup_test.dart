import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/domain/entities/mcp_setup.dart';
import 'package:work_nexus/features/chat/domain/repositories/mcp_setup_repository.dart';
import 'package:work_nexus/features/chat/domain/usecases/build_mcp_client_configs.dart';
import 'package:work_nexus/features/chat/domain/usecases/prepare_mcp_setup.dart';
import 'package:work_nexus/features/chat/domain/value_objects/mcp_client_config.dart';

class _MockRepo extends Mock implements McpSetupRepository {}

void main() {
  group('McpSetup.nodeSupported', () {
    bool supported(String? v) =>
        McpSetup(scriptPath: '/s', nodeVersion: v).nodeSupported;

    test('needs Node.js 22.13 or newer', () {
      expect(supported('v22.13.0'), isTrue);
      expect(supported('v22.20.1'), isTrue);
      expect(supported('v25.2.1'), isTrue);
      expect(supported('v22.12.9'), isFalse);
      expect(supported('v20.19.0'), isFalse);
    });

    test('is false without a readable version', () {
      expect(supported(null), isFalse);
      expect(supported('garbage'), isFalse);
    });
  });

  group('BuildMcpClientConfigs', () {
    const setup = McpSetup(
      scriptPath:
          '/Users/me/Library/Application Support/x/mcp/worknexus-mcp.mjs',
      nodePath: '/opt/homebrew/bin/node',
      nodeVersion: 'v25.2.1',
    );

    test('quotes the absolute paths in the Claude Code command', () {
      final code = const BuildMcpClientConfigs()(setup, McpHostOs.macos).first;
      expect(code.client, McpClient.claudeCode);
      expect(
        code.snippet,
        'claude mcp add worknexus -s user -- "/opt/homebrew/bin/node" '
        '"/Users/me/Library/Application Support/x/mcp/worknexus-mcp.mjs"',
      );
    });

    test('gives Claude Desktop a valid mcpServers entry on macOS', () {
      final configs = const BuildMcpClientConfigs()(setup, McpHostOs.macos);
      expect(configs.map((c) => c.client), [
        McpClient.claudeCode,
        McpClient.claudeDesktop,
        McpClient.other,
      ]);
      final desktop = configs[1];
      expect(desktop.configFile, contains('Application Support/Claude'));
      expect(jsonDecode(desktop.snippet), {
        'mcpServers': {
          'worknexus': {
            'command': '/opt/homebrew/bin/node',
            'args': [setup.scriptPath],
          },
        },
      });
    });

    test('escapes Windows paths in JSON and points at %APPDATA%', () {
      const win = McpSetup(
        scriptPath: r'C:\Users\me\AppData\Roaming\WorkNexus\mcp\w.mjs',
        nodePath: r'C:\Program Files\nodejs\node.exe',
        nodeVersion: 'v22.13.0',
      );
      final desktop = const BuildMcpClientConfigs()(win, McpHostOs.windows)[1];
      expect(desktop.configFile, startsWith('%APPDATA%'));
      expect(jsonDecode(desktop.snippet), {
        'mcpServers': {
          'worknexus': {
            'command': win.nodePath,
            'args': [win.scriptPath],
          },
        },
      });
    });

    test('has no Claude Desktop entry on Linux, and falls back to node', () {
      const linux = McpSetup(scriptPath: '/home/me/.local/share/w.mjs');
      final configs = const BuildMcpClientConfigs()(linux, McpHostOs.linux);
      expect(configs.map((c) => c.client), [
        McpClient.claudeCode,
        McpClient.other,
      ]);
      expect(configs.first.snippet, contains('-- "node" '));
    });
  });

  group('PrepareMcpSetup', () {
    test('passes on what the repository prepares', () async {
      final repo = _MockRepo();
      when(
        repo.prepare,
      ).thenAnswer((_) async => const Ok(McpSetup(scriptPath: '/s')));
      final result = await PrepareMcpSetup(repo)();
      expect(result.valueOrNull?.scriptPath, '/s');
    });

    test('passes on a failure', () async {
      final repo = _MockRepo();
      when(
        repo.prepare,
      ).thenAnswer((_) async => const Err(StorageFailure('disk full')));
      expect(await PrepareMcpSetup(repo)(), isA<Err<McpSetup>>());
    });
  });
}
