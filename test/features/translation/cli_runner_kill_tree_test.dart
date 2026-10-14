import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/translation/data/datasources/cli_runner.dart';

/// A shell that runs a long-lived child of its own, with its output piped here:
/// the pipes stay open for as long as the child lives, so they closing is how
/// the test sees the child stopped. On Windows that is `cmd /c` around `ping`
/// (what an npm `.cmd` shim looks like); elsewhere `sh -c` around `sleep`.
Future<Process> _shellWithChild() => Platform.isWindows
    ? Process.start('cmd', ['/c', 'ping -n 30 127.0.0.1'])
    : Process.start('/bin/sh', ['-c', 'sleep 30; echo done']);

void main() {
  test(
    'killTree stops what the process started, not only the process',
    timeout: const Timeout(Duration(seconds: 30)),
    () async {
      final process = await _shellWithChild();
      final output = process.stdout.transform(utf8.decoder).join();
      unawaited(process.stderr.drain<void>());
      // Time for the shell to start its child.
      await Future<void>.delayed(const Duration(milliseconds: 700));

      await const CliRunner().killTree(process);

      await process.exitCode.timeout(const Duration(seconds: 5));
      // Only once the child is gone do the pipes close.
      await output.timeout(
        const Duration(seconds: 5),
        onTimeout: () => fail('the child of the process is still running'),
      );
    },
  );
}
