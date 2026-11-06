import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/features/translation/data/datasources/cli_runner.dart';

abstract class _ProcessLauncher {
  Future<ProcessResult> run(String executable, List<String> args);
}

class _MockProcessLauncher extends Mock implements _ProcessLauncher {}

const _npm = r'C:\Users\dev\AppData\Roaming\npm';

const _windowsEnv = {
  'PATH': '$_npm;C:\\Windows\\system32',
  'PATHEXT': '.COM;.EXE;.BAT;.CMD',
  'APPDATA': r'C:\Users\dev\AppData\Roaming',
  'USERPROFILE': r'C:\Users\dev',
  'LOCALAPPDATA': r'C:\Users\dev\AppData\Local',
};

ProcessResult _result(int exitCode, String stdout) =>
    ProcessResult(0, exitCode, stdout, '');

void main() {
  late _MockProcessLauncher launcher;

  setUp(() => launcher = _MockProcessLauncher());

  CliRunner windowsRunner({Set<String> files = const {}}) => CliRunner(
    isWindows: true,
    environment: _windowsEnv,
    runProcess: launcher.run,
    fileExists: files.contains,
  );

  group('CliRunner.resolve on Windows', () {
    test(
      'skips the extension-less npm shim that `where` lists first',
      () async {
        // What `where opencode` prints for an npm global install (CRLF lines).
        when(() => launcher.run('where', ['opencode'])).thenAnswer(
          (_) async => _result(
            0,
            '$_npm\\opencode\r\n$_npm\\opencode.cmd\r\n$_npm\\opencode.ps1\r\n',
          ),
        );

        final path = await windowsRunner().resolve('opencode');

        expect(path, '$_npm\\opencode.cmd');
      },
    );

    test('keeps a native .exe hit as is', () async {
      when(() => launcher.run('where', ['opencode'])).thenAnswer(
        (_) async =>
            _result(0, 'C:\\Users\\dev\\scoop\\shims\\opencode.EXE\r\n'),
      );

      final path = await windowsRunner().resolve('opencode');

      expect(path, r'C:\Users\dev\scoop\shims\opencode.EXE');
    });

    test(
      'falls back to the npm dir when `where` finds nothing on PATH',
      () async {
        when(
          () => launcher.run('where', ['opencode']),
        ).thenAnswer((_) async => _result(1, ''));
        final runner = CliRunner(
          isWindows: true,
          environment: {..._windowsEnv, 'PATH': r'C:\Windows\system32'},
          runProcess: launcher.run,
          // The extension-less script exists too; it must not be picked.
          fileExists: {'$_npm\\opencode', '$_npm\\opencode.cmd'}.contains,
        );

        expect(await runner.resolve('opencode'), '$_npm\\opencode.cmd');
      },
    );

    test('never returns an extension-less file from the PATH scan', () async {
      when(
        () => launcher.run('where', ['opencode']),
      ).thenAnswer((_) async => _result(1, ''));

      final path = await windowsRunner(
        files: {'$_npm\\opencode'},
      ).resolve('opencode');

      expect(path, isNull);
    });
  });

  test('macOS/Linux still asks a login shell', () async {
    when(
      () => launcher.run('/bin/zsh', ['-lic', 'command -v opencode']),
    ).thenAnswer(
      (_) async => _result(0, 'banner\n/Users/dev/.opencode/bin/opencode\n'),
    );
    final runner = CliRunner(
      isWindows: false,
      environment: const {'SHELL': '/bin/zsh', 'PATH': '/usr/bin'},
      runProcess: launcher.run,
      fileExists: (_) => false,
    );

    expect(
      await runner.resolve('opencode'),
      '/Users/dev/.opencode/bin/opencode',
    );
  });
}
