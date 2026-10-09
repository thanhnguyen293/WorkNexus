// The fake `opencode` is a `/bin/sh -c` script, so this runs on POSIX hosts
// only (CI runs it on Linux).
@TestOn('posix')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/adapters/translation_service.dart';
import 'package:work_nexus/core/domain/entities/translation_record.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/platform/agent_runner.dart';
import 'package:work_nexus/features/translation/data/opencode_translation_service.dart';

/// Regression for the "Translate spins forever" report: `opencode run` has no
/// deadline of its own, and a queued or unauthenticated model can leave it
/// running for minutes. The service must kill it and come back with a failure.
class _ScriptedRunner extends AgentRunner {
  const _ScriptedRunner(this.script);

  /// A `sh -c` script standing in for the `opencode` binary.
  final String script;

  @override
  Future<String?> resolve(String name, {String? override}) async => '/bin/sh';

  @override
  Future<Process> start(
    String executable,
    List<String> args, {
    required String workingDir,
    Map<String, String>? extraEnv,
  }) => Process.start('/bin/sh', ['-c', script]);
}

/// The value of an [Ok] result, typed from the [Result] (fails the test on Err).
T _ok<T>(Result<T> result) => (result as Ok<T>).value;

void main() {
  const source = TicketSource(title: 'Fix login', body: 'It does not respond.');

  Future<Result<TranslationRecord>> translateWith(
    String script, {
    Duration timeout = const Duration(seconds: 30),
  }) =>
      OpenCodeTranslationService(
        runner: _ScriptedRunner(script),
        timeout: timeout,
      ).translate(
        ticketId: 't-1',
        source: source,
        sourceHash: 'hash-1',
        targetLang: 'vi',
      );

  test(
    'a CLI that never answers is killed and reported, not awaited',
    () async {
      final sw = Stopwatch()..start();
      final res = await translateWith(
        'sleep 30',
        timeout: const Duration(milliseconds: 300),
      );
      sw.stop();

      expect(res, isA<Err<dynamic>>());
      expect(
        (res as Err).failure,
        isA<AgentFailure>().having(
          (f) => f.message,
          'message',
          contains('did not answer'),
        ),
      );
      // Proof the child was actually killed rather than merely abandoned.
      expect(sw.elapsed, lessThan(const Duration(seconds: 10)));
    },
  );

  test('a provider error reaches the user with the CLI\'s own words', () async {
    final res = await translateWith(
      'echo "Token refresh failed: 401" >&2; exit 1',
    );

    expect(
      (res as Err).failure.message,
      allOf(contains('exited 1'), contains('Token refresh failed: 401')),
    );
  });

  test('terminal colour codes are stripped from the reported error', () async {
    // Shaped like what `opencode run` writes when a model is unavailable.
    final res = await translateWith(
      r"printf '\033[91m\033[1mError: \033[0mmodel requires opt in\n' >&2; "
      'exit 1',
    );

    final message = (res as Err).failure.message;
    expect(message, contains('Error: model requires opt in'));
    expect(message, isNot(contains('')));
  });

  test('a successful run is parsed into a record', () async {
    final res = await translateWith(
      r'''echo '{"title":"Sửa đăng nhập","body":"Không phản hồi."}' ''',
    );

    expect(res, isA<Ok<dynamic>>());
    final record = _ok(res);
    expect(record.translatedTitle, 'Sửa đăng nhập');
    expect(record.translatedBody, 'Không phản hồi.');
    expect(record.targetLang, 'vi');
    expect(record.sourceHash, 'hash-1');
  });

  test(
    'output with no JSON in it is a parse failure that quotes the output',
    () async {
      final res = await translateWith('echo "usage: opencode run [message..]"');

      expect(
        (res as Err).failure,
        isA<ParseFailure>().having(
          (f) => f.message,
          'message',
          contains('usage: opencode run'),
        ),
      );
    },
  );

  test('cancel stops an in-flight run', () async {
    final service = OpenCodeTranslationService(
      runner: const _ScriptedRunner('sleep 30'),
    );
    final pending = service.translate(
      ticketId: 't-1',
      source: source,
      sourceHash: 'hash-1',
      targetLang: 'vi',
    );
    // Give the subprocess a moment to exist before asking for it to stop.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await service.cancel('t-1');

    expect(await pending, isA<Err<dynamic>>());
  });
}
