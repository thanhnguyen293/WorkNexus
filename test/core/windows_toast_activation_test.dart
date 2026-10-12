import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/platform/windows_toast_activation.dart';

void main() {
  const exe = r'C:\Apps\WorkNexus\WorkNexus.exe';
  const key =
      r'HKCU\Software\Classes\CLSID\{11111111-2222-3333-4444-555555555555}\LocalServer32';

  /// Records each command and answers `reg query` with [registered].
  ({List<List<String>> calls, WindowsToastActivation activation}) fake({
    String? registered,
    int addExit = 0,
  }) {
    final calls = <List<String>>[];
    return (
      calls: calls,
      activation: WindowsToastActivation(
        guid: '11111111-2222-3333-4444-555555555555',
        exePath: exe,
        run: (executable, arguments) async {
          calls.add([executable, ...arguments]);
          if (arguments.first == 'query') {
            return registered == null
                ? ProcessResult(0, 1, '', 'not found')
                : ProcessResult(
                    0,
                    0,
                    '\r\n$key\r\n    (Default)    REG_SZ    $registered\r\n',
                    '',
                  );
          }
          return ProcessResult(0, addExit, '', addExit == 0 ? '' : 'denied');
        },
      ),
    );
  }

  test('writes the key, quoting the exe, when there is none', () async {
    final f = fake();

    expect(await f.activation.ensureRegistered(), isTrue);

    expect(f.calls.last, ['reg', 'add', key, '/ve', '/d', '"$exe"', '/f']);
  });

  test('leaves a key that already names this exe alone', () async {
    final f = fake(registered: '"${exe.toLowerCase()}"');

    expect(await f.activation.ensureRegistered(), isTrue);

    expect(f.calls.map((c) => c[1]), ['query']);
  });

  test('points a key naming another copy of the app at this one', () async {
    final f = fake(registered: r'"D:\Old\WorkNexus.exe"');

    await f.activation.ensureRegistered();

    expect(f.calls.map((c) => c[1]), ['query', 'add']);
  });

  test('a refused write is reported, not thrown', () async {
    final f = fake(addExit: 1);

    expect(await f.activation.ensureRegistered(), isFalse);
  });
}
