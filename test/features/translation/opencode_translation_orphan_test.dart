import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/translation/data/datasources/cli_runner.dart';
import 'package:work_nexus/features/translation/data/opencode_translation_service.dart';
import 'package:work_nexus/features/translation/domain/adapters/translation_service.dart';

/// A CLI that dies when killed but leaves a child of its own holding its output
/// pipes open — what a shell shim around the real binary does under `dash`
/// (`sh -c 'sleep 30'` forks `sleep`, and killing the `sh` does not stop it).
/// The pipes here are never closed. The service must not wait for them once it
/// has killed the process, or the "killed" CLI would hold the caller for as long
/// as the child lives. The real-shell version of this lives in
/// `opencode_translation_timeout_test.dart`, which runs on POSIX hosts and
/// reproduces the orphan only where `/bin/sh` is dash.
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

class _MockRunner extends Mock implements CliRunner {}

void main() {
  const source = TicketSource(title: 'Fix login', body: 'It does not respond.');
  late _MockRunner runner;
  late List<_OrphanedProcess> started;

  setUpAll(() => registerFallbackValue(_OrphanedProcess()));

  setUp(() {
    runner = _MockRunner();
    started = [];
    when(
      () => runner.resolve(any(), override: any(named: 'override')),
    ).thenAnswer((_) async => 'opencode');
    when(
      () => runner.start(
        any(),
        any(),
        workingDir: any(named: 'workingDir'),
        extraEnv: any(named: 'extraEnv'),
      ),
    ).thenAnswer((_) async {
      final process = _OrphanedProcess();
      started.add(process);
      return process;
    });
    // Stops the process, leaves its pipes open.
    when(() => runner.killTree(any())).thenAnswer((call) async {
      (call.positionalArguments.first as Process).kill();
    });
  });

  Future<Result<dynamic>> translate(
    OpenCodeTranslationService service, {
    String ticketId = 't-1',
  }) => service.translate(
    ticketId: ticketId,
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
          runner: runner,
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
      // The process and what it started are stopped, not just abandoned.
      verify(() => runner.killTree(started.single)).called(1);
    },
  );

  test(
    'cancel does not wait for pipes a child of the CLI still holds open',
    timeout: const Timeout(Duration(seconds: 20)),
    () async {
      final service = OpenCodeTranslationService(runner: runner);
      final pending = translate(service);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await service.cancel('t-1');

      expect(await pending, isA<Err<dynamic>>());
      verify(() => runner.killTree(started.single)).called(1);
    },
  );

  test(
    'cancelling a run does not touch the newer run of the same key',
    timeout: const Timeout(Duration(seconds: 20)),
    () async {
      final service = OpenCodeTranslationService(runner: runner);
      final first = translate(service);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await service.cancel('t-1');
      // Starts again while the first run is still winding down.
      final second = translate(service);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(started, hasLength(2));
      await first;

      // The first run finishing did not drop the second's entry, so cancel
      // still finds and stops it.
      await service.cancel('t-1');
      expect(await second, isA<Err<dynamic>>());
      verify(() => runner.killTree(started.last)).called(1);
    },
  );
}
