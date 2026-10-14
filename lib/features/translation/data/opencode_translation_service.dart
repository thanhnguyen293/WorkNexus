import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/domain/entities/translation_record.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/util/content_hash.dart';
import '../../../core/util/translation_languages.dart';
import '../domain/adapters/translation_service.dart';
import 'datasources/cli_runner.dart';
import 'translation_prompts.dart';

/// How long a single `opencode run` may take before we give up and kill it.
///
/// The CLI has no timeout of its own: an unauthenticated provider, a queued
/// free-tier model or a stalled request can leave it running indefinitely,
/// which used to leave the Translate button spinning forever. Generous enough
/// for a long ticket body on a slow model, short enough to surface a problem.
const Duration kOpenCodeTranslationTimeout = Duration(seconds: 120);

/// Terminal styling (colour/bold) the CLI writes around its own messages.
final RegExp _ansiEscape = RegExp(r'\x1B\[[0-9;]*[a-zA-Z]');

/// Real OpenCode-backed translation via the `opencode run` CLI. Registered as
/// the [TranslationService] in the GetIt service locator (`configureDependencies`).
///
/// It uses OpenCode's **own** authentication (`opencode auth login`) and the
/// configured default model, so translations run through your normal provider
/// (e.g. OpenCode Go) and show up in its usage/quota. Pass a model (per call, or
/// [model] as the fallback) to pin a specific one (e.g.
/// `opencode-go/deepseek-v4-pro`); leave it null to use whatever your OpenCode
/// config defaults to. We deliberately do NOT inject a provider API key into the
/// environment — that would reroute the call onto a different provider and
/// bypass your OpenCode usage tracking.
class OpenCodeTranslationService implements TranslationService {
  OpenCodeTranslationService({
    CliRunner? runner,
    this.model,
    this.workingDir,
    this.binaryOverride,
    this.timeout = kOpenCodeTranslationTimeout,
  }) : _runner = runner ?? CliRunner();

  final CliRunner _runner;

  /// Fallback model id (`provider/model`) when a call doesn't pin one. Null ⇒
  /// OpenCode's configured default.
  final String? model;

  /// Directory the run is executed in (session grouping). Null ⇒ the user's home.
  final String? workingDir;
  final String? binaryOverride;

  /// Deadline for one translation run.
  final Duration timeout;

  /// In-flight CLI processes by ticket id, so [cancel] can kill one.
  final Map<String, Process> _running = <String, Process>{};

  /// Processes that were killed (a timeout or [cancel]), which their run then
  /// stops waiting on the pipes of. Tracked here, not inferred from
  /// [_running]: a new run of the same key may have taken its entry by then.
  final Set<Process> _killed = <Process>{};

  static const _templateVersion = 'oc-v2';

  @override
  String contentHash(TicketSource source) =>
      contentHash2(source.title, source.body);

  @override
  Future<void> cancel(String ticketId) async {
    final process = _running.remove(ticketId);
    if (process == null) return;
    _killed.add(process);
    await _runner.killTree(process);
  }

  @override
  Future<Result<TranslationRecord>> translate({
    required String ticketId,
    required TicketSource source,
    required String sourceHash,
    required String targetLang,
    String? model,
  }) async {
    final path = await _runner.resolve('opencode', override: binaryOverride);
    if (path == null) {
      return const Err(AgentFailure('opencode not found on PATH'));
    }
    final home = Platform.isWindows
        ? Platform.environment['USERPROFILE']
        : Platform.environment['HOME'];
    final cwd = workingDir ?? home ?? Directory.current.path;
    final language = translationLanguageFor(targetLang);
    final chosenModel = _firstNonEmpty(model, this.model);
    final prompt = ticketPrompt(source, language.englishName);
    try {
      final run = await _run(
        ticketId: ticketId,
        path: path,
        args: [
          'run',
          if (chosenModel != null) ...['-m', chosenModel],
          prompt,
        ],
        cwd: cwd,
      );
      if (run.timedOut) {
        return Err(
          AgentFailure(
            'OpenCode did not answer within ${timeout.inSeconds}s and was '
            'stopped. Check `opencode run` in a terminal — the model may be '
            'unauthenticated or queued.',
          ),
        );
      }
      if (run.exitCode != 0) {
        return Err(AgentFailure(_exitMessage(run)));
      }
      final parsed = extractTicketJson(run.stdout);
      if (parsed == null) {
        return Err(ParseFailure(_unparsableMessage(run)));
      }
      return Ok(
        TranslationRecord(
          ticketId: ticketId,
          sourceHash: sourceHash,
          targetLang: language.code,
          translatedTitle: parsed['title']?.toString() ?? source.title,
          translatedBody: parsed['body']?.toString() ?? source.body,
          model: chosenModel ?? 'opencode default',
          templateVersion: _templateVersion,
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      return Err(AgentFailure('OpenCode translation failed: $e', cause: e));
    }
  }

  @override
  Future<Result<TextTranslation>> translateText({
    required String key,
    required String text,
    required String targetLang,
    String? model,
  }) async {
    final path = await _runner.resolve('opencode', override: binaryOverride);
    if (path == null) {
      return const Err(AgentFailure('opencode not found on PATH'));
    }
    final home = Platform.isWindows
        ? Platform.environment['USERPROFILE']
        : Platform.environment['HOME'];
    final chosenModel = _firstNonEmpty(model, this.model);
    final language = translationLanguageFor(targetLang);
    final prompt = textPrompt(text, language.englishName);
    try {
      final run = await _run(
        ticketId: key,
        path: path,
        args: [
          'run',
          if (chosenModel != null) ...['-m', chosenModel],
          prompt,
        ],
        cwd: workingDir ?? home ?? Directory.current.path,
      );
      if (run.timedOut) {
        return Err(
          AgentFailure('OpenCode did not answer within ${timeout.inSeconds}s.'),
        );
      }
      if (run.exitCode != 0) return Err(AgentFailure(_exitMessage(run)));
      final out = run.stdout.replaceAll(_ansiEscape, '').trim();
      if (out.isEmpty) return Err(ParseFailure(_unparsableMessage(run)));
      return Ok(TextTranslation(out, model: chosenModel));
    } catch (e) {
      return Err(AgentFailure('OpenCode translation failed: $e', cause: e));
    }
  }

  /// Spawns the CLI and collects its output under [timeout]. `Process.run` has
  /// no deadline, so we drive the process ourselves and kill it — with whatever
  /// it started — when the timer fires; otherwise a stalled CLI hangs the
  /// caller forever.
  Future<_CliRun> _run({
    required String ticketId,
    required String path,
    required List<String> args,
    required String cwd,
  }) async {
    final process = await _runner.start(path, args, workingDir: cwd);
    _running[ticketId] = process;
    // Nothing is piped in; leaving stdin open makes CLIs that read piped input
    // block until EOF.
    unawaited(process.stdin.close().catchError((_) {}));
    final stdout = _Capture(process.stdout);
    final stderr = _Capture(process.stderr);
    var timedOut = false;
    final deadline = Timer(timeout, () {
      timedOut = true;
      _killed.add(process);
      unawaited(_runner.killTree(process));
    });
    try {
      final exitCode = await process.exitCode;
      deadline.cancel();
      // Whatever it started is stopped with it, but a child that outlives it
      // (or a platform that cannot find it) can still hold the output pipes
      // open for as long as it lives. A killed run takes what has arrived and
      // stops waiting, both pipes at once; a run that ended by itself waits for
      // them to close.
      final grace = _killed.contains(process) ? _killedOutputGrace : null;
      final output = await Future.wait([
        stdout.text(within: grace),
        stderr.text(within: grace),
      ]);
      return _CliRun(
        exitCode: exitCode,
        stdout: output[0],
        stderr: output[1],
        timedOut: timedOut,
      );
    } finally {
      deadline.cancel();
      _killed.remove(process);
      // A newer run of the same key may have taken the entry: leave it.
      if (identical(_running[ticketId], process)) _running.remove(ticketId);
    }
  }

  /// The CLI reports provider/auth problems on stderr; surface that verbatim so
  /// "Token refresh failed: 401" reaches the user instead of a bare exit code.
  String _exitMessage(_CliRun run) {
    final detail = _firstNonEmpty(run.stderr.trim(), run.stdout.trim());
    return detail == null
        ? 'OpenCode exited ${run.exitCode}'
        : 'OpenCode exited ${run.exitCode}: ${_tail(detail)}';
  }

  String _unparsableMessage(_CliRun run) {
    final detail = _firstNonEmpty(run.stdout.trim(), run.stderr.trim());
    return detail == null
        ? 'OpenCode returned nothing to translate'
        : 'Could not parse OpenCode translation: ${_tail(detail)}';
  }

  /// The last few lines of CLI output — enough to explain the failure without
  /// dumping a whole transcript into a snackbar. The CLI styles its output for
  /// a terminal, so the escape codes are stripped: the UI shows plain text
  /// instead of `^[[91m^[[1mError:`.
  String _tail(String output, {int lines = 4, int maxChars = 400}) {
    final kept = output
        .replaceAll(_ansiEscape, '')
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final tail = kept.length <= lines
        ? kept
        : kept.sublist(kept.length - lines);
    final joined = tail.join(' · ');
    return joined.length <= maxChars
        ? joined
        : '${joined.substring(0, maxChars)}…';
  }

  String? _firstNonEmpty(String? a, String? b) {
    final first = a?.trim();
    if (first != null && first.isNotEmpty) return first;
    final second = b?.trim();
    return second != null && second.isNotEmpty ? second : null;
  }
}

/// One completed (or killed) CLI invocation.
class _CliRun {
  const _CliRun({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.timedOut,
  });

  final int exitCode;
  final String stdout;
  final String stderr;

  /// True when the deadline fired and we killed the process.
  final bool timedOut;
}

/// Shared hashing so the service and cache agree on the content hash.
String contentHash2(String title, String body) => contentHash(title, body);

/// How long a killed CLI's output pipes get to close before the run stops
/// waiting for them.
const _killedOutputGrace = Duration(seconds: 1);

/// Reads a CLI's output pipe as text as it arrives, so a run can stop waiting
/// for the pipe to close and still keep what has been read.
class _Capture {
  _Capture(Stream<List<int>> pipe) {
    _reading = pipe
        .transform(utf8.decoder)
        .listen(
          _text.write,
          onError: (Object e, StackTrace s) {
            if (_error == null) {
              _error = e;
              _stack = s;
            }
          },
          onDone: _closed.complete,
        );
  }

  final _text = StringBuffer();
  final _closed = Completer<void>();
  late final StreamSubscription<String> _reading;
  Object? _error;
  StackTrace? _stack;

  /// What the pipe carried. Waits for it to close, or, given [within], at most
  /// that long, after which it stops reading. A decoding error is rethrown.
  Future<String> text({Duration? within}) async {
    if (within == null) {
      await _closed.future;
    } else {
      await _closed.future.timeout(within, onTimeout: () {});
    }
    await _reading.cancel();
    final error = _error;
    if (error != null) Error.throwWithStackTrace(error, _stack!);
    return _text.toString();
  }
}
