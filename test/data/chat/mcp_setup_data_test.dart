import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/data/datasources/mcp_script_installer.dart';
import 'package:work_nexus/features/chat/data/datasources/node_runtime_probe.dart';
import 'package:work_nexus/features/chat/data/repositories/local_mcp_setup_repository.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.content);

  String? content;

  @override
  Future<ByteData> load(String key) async {
    final c = content;
    if (key != McpScriptInstaller.asset || c == null) {
      throw FlutterError('Unable to load asset: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(c)));
  }
}

void main() {
  group('NodeRuntimeProbe', () {
    test('asks the login shell, then checks the version', () async {
      final calls = <String>[];
      final probe = NodeRuntimeProbe(
        isWindows: false,
        environment: {'SHELL': '/bin/zsh'},
        run: (exe, args) async {
          calls.add('$exe ${args.join(' ')}');
          if (exe == '/bin/zsh') return '/Users/me/.nvm/bin/node\n';
          if (exe == '/Users/me/.nvm/bin/node') return 'v22.14.0\n';
          return null;
        },
      );
      expect((await probe.findAll()).first, (
        path: '/Users/me/.nvm/bin/node',
        version: 'v22.14.0',
      ));
      // Found by the login shell: no interactive shell needed.
      expect(calls.where((c) => c.contains('-lic')), isEmpty);
    });

    test('falls back to the usual install places', () async {
      final probe = NodeRuntimeProbe(
        isWindows: false,
        environment: const {},
        run: (exe, args) async =>
            exe == '/usr/local/bin/node' ? 'v23.0.0' : null,
      );
      expect((await probe.findAll()).single.path, '/usr/local/bin/node');
    });

    test('uses where on Windows', () async {
      final probe = NodeRuntimeProbe(
        isWindows: true,
        environment: const {},
        run: (exe, args) async => switch (exe) {
          'where' => 'C:\\Program Files\\nodejs\\node.exe\r\n',
          'C:\\Program Files\\nodejs\\node.exe' => 'v22.13.1\r\n',
          _ => null,
        },
      );
      expect(await probe.findAll(), [
        (path: r'C:\Program Files\nodejs\node.exe', version: 'v22.13.1'),
      ]);
    });

    test('is null when there is no node', () async {
      final probe = NodeRuntimeProbe(
        isWindows: false,
        environment: const {},
        run: (_, _) async => null,
      );
      expect(await probe.findAll(), isEmpty);
    });

    test('lists every node that runs, once each, PATH order first', () async {
      final probe = NodeRuntimeProbe(
        isWindows: false,
        environment: {'SHELL': '/bin/zsh'},
        run: (exe, args) async => switch (exe) {
          '/bin/zsh' => '/usr/local/bin/node\n',
          '/usr/local/bin/node' => 'v18.20.0',
          '/opt/homebrew/bin/node' => 'v25.2.1',
          _ => null,
        },
      );
      expect(await probe.findAll(), [
        (path: '/usr/local/bin/node', version: 'v18.20.0'),
        (path: '/opt/homebrew/bin/node', version: 'v25.2.1'),
      ]);
    });

    test('resolves fnm per-shell links and shims to the real node', () async {
      const fnm = '/Users/me/.local/state/fnm_multishells/42_17/bin/node';
      const real =
          '/Users/me/.local/share/fnm/node-versions/v22.14.0/'
          'installation/bin/node';
      final probe = NodeRuntimeProbe(
        isWindows: false,
        environment: {'SHELL': '/bin/zsh'},
        run: (exe, args) async => switch ((exe, args.first)) {
          ('/bin/zsh', _) => '$fnm\n',
          (fnm, '--version') => 'v22.14.0',
          (fnm, '-p') => '$real\n',
          _ => null,
        },
      );
      expect((await probe.findAll()).single.path, real);
    });

    test(
      'keeps a Homebrew link as it is, though it points into a version',
      () async {
        final calls = <String>[];
        final probe = NodeRuntimeProbe(
          isWindows: false,
          environment: const {},
          run: (exe, args) async {
            calls.add('$exe ${args.join(' ')}');
            return exe == '/opt/homebrew/bin/node' ? 'v25.2.1' : null;
          },
        );
        expect((await probe.findAll()).single.path, '/opt/homebrew/bin/node');
        expect(calls.where((c) => c.contains('execPath')), isEmpty);
      },
    );
  });

  group('McpScriptInstaller', () {
    late Directory dir;

    setUp(() async => dir = await Directory.systemTemp.createTemp('wn_mcp'));
    tearDown(() => dir.delete(recursive: true));

    test('copies the script, and rewrites it only when it changed', () async {
      final bundle = _Bundle('v1');
      final installer = McpScriptInstaller(
        bundle: bundle,
        directory: () async => Directory('${dir.path}/mcp'),
      );
      final path = await installer.install();
      expect(path, '${dir.path}/mcp/${McpScriptInstaller.fileName}');
      expect(await File(path).readAsString(), 'v1');

      final before = (await File(path).stat()).modified;
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await installer.install();
      expect((await File(path).stat()).modified, before);

      bundle.content = 'v2';
      await installer.install();
      expect(await File(path).readAsString(), 'v2');
    });

    test('refresh updates an installed copy and creates none', () async {
      final bundle = _Bundle('v1');
      final installer = McpScriptInstaller(
        bundle: bundle,
        directory: () async => Directory('${dir.path}/mcp'),
      );
      expect(await installer.refresh(), isNull);
      expect(await Directory('${dir.path}/mcp').exists(), isFalse);

      final path = await installer.install();
      bundle.content = 'v2';
      expect(await installer.refresh(), path);
      expect(await File(path).readAsString(), 'v2');
    });
  });

  group('LocalMcpSetupRepository', () {
    late Directory dir;

    setUp(() async => dir = await Directory.systemTemp.createTemp('wn_mcp'));
    tearDown(() => dir.delete(recursive: true));

    LocalMcpSetupRepository repo(
      String? script, {
      Map<String, String> nodes = const {'/usr/bin/node': 'v22.13.0'},
    }) => LocalMcpSetupRepository(
      installer: McpScriptInstaller(
        bundle: _Bundle(script),
        directory: () async => dir,
      ),
      probe: NodeRuntimeProbe(
        isWindows: false,
        environment: const {},
        run: (exe, _) async => nodes[exe],
      ),
    );

    test('returns the installed script and the node found', () async {
      final setup = (await repo('js').prepare()).valueOrNull;
      expect(setup?.scriptPath, endsWith(McpScriptInstaller.fileName));
      expect(setup?.nodePath, '/usr/bin/node');
      expect(setup?.nodeSupported, isTrue);
    });

    test(
      'prefers a recent enough node over an older one found first',
      () async {
        final setup = (await repo(
          'js',
          nodes: {
            '/usr/local/bin/node': 'v18.20.0',
            '/usr/bin/node': 'v22.13.0',
          },
        ).prepare()).valueOrNull;
        expect(setup?.nodePath, '/usr/bin/node');
      },
    );

    test('still names an old node when there is no other', () async {
      final setup = (await repo(
        'js',
        nodes: {'/usr/local/bin/node': 'v18.20.0'},
      ).prepare()).valueOrNull;
      expect(setup?.nodePath, '/usr/local/bin/node');
      expect(setup?.nodeSupported, isFalse);
    });

    test('a build without the asset is a NotFoundFailure', () async {
      final result = await repo(null).prepare();
      expect((result as Err).failure, isA<NotFoundFailure>());
    });

    test('refreshing writes nothing when it was never set up', () async {
      expect(await repo('js').refreshInstalledScript(), isA<Ok<void>>());
      expect(
        await File('${dir.path}/${McpScriptInstaller.fileName}').exists(),
        isFalse,
      );
    });
  });
}
