import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/translation/data/datasources/cli_runner.dart';
import 'package:work_nexus/features/translation/data/opencode_translation_service.dart';
import 'package:work_nexus/features/translation/domain/adapters/translation_service.dart';

/// A CLI that dies when killed but leaves a child of its own holding its output
/// pipes open — what a shell shim around the real binary does under `dash`
/// (`sh -c 'sleep 30'` forks `sleep`, and killing the `sh` does not stop it).
/// The pipes here are never closed. The service must not wait for them once it
/// has killed the process, or the "killed" CLI would hold the caller for as
/// long as the child lives. The OS-specific version of this lives in
/// `opencode_translation_timeout_test.dart`, which only runs where `/bin/sh`
/// is dash.
class _OrphanedProcess implements Process {
  final _stdout = StreamController<List<int>>();
  final _stderr = StreamController<List<int>>();
  final _exit = Completer<int>();

  @override
  int get pid => 1;

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => _stderr.stream;

  @override
  IOSink get stdin => IOSink(StreamController<List<int>>());

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (!_exit.isCompleted) _exit.complete(-15);
    return true;
  }
}

class _OrphanRunner extends CliRunner {
  const _OrphanRunner();

  @override
  Future<String?> resolve(String name, {String? override}) async => 'opencode';

  @override
  Future<Process> start(
    String executable,
    List<String> args, {
    required String workingDir,
    Map<String, String>? extraEnv,
  }) async => _OrphanedProcess();
}

void main() {
  const source = TicketSource(title: 'Fix login', body: 'It does not respond.');

  Future<Result<dynamic>> translate(OpenCodeTranslationService service) =>
      service.translate(
        ticketId: 't-1',
        source: source,
        sourceHash: 'hash-1',
        targetLang: 'vi',
      );

  test(
    'a timeout does not wait for pipes a child of the CLI still holds open',
    timeout: const Timeout(Duration(seconds: 20)),
    () async {
      final res = await translate(
        OpenCodeTranslationService(
          runner: const _OrphanRunner(),
          timeout: const Duration(milliseconds: 200),
        ),
      );

      expect(
        (res as Err).failure,
        isA<AgentFailure>().having(
          (f) => f.message,
          'message',
          contains('did not answer'),
        ),
      );
    },
  );

  test(
    'cancel does not wait for pipes a child of the CLI still holds open',
    timeout: const Timeout(Duration(seconds: 20)),
    () async {
      final service = OpenCodeTranslationService(runner: const _OrphanRunner());
      final pending = translate(service);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await service.cancel('t-1');

      expect(await pending, isA<Err<dynamic>>());
    },
  );
}
