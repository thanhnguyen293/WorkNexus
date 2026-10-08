import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/domain/entities/translation_record.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/util/content_hash.dart';
import '../../../core/util/translation_languages.dart';
import '../../agents/data/cli_agent_adapters.dart';
import '../domain/adapters/translation_service.dart';

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
    AgentRunner runner = const AgentRunner(),
    this.model,
    this.workingDir,
    this.binaryOverride,
    this.timeout = kOpenCodeTranslationTimeout,
  }) : _runner = runner;

  final AgentRunner _runner;

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

  static const _templateVersion = 'oc-v2';

  @override
  String contentHash(TicketSource source) =>
      contentHash2(source.title, source.body);

  @override
  Future<void> cancel(String ticketId) async {
    _running.remove(ticketId)?.kill();
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
    final prompt = _buildPrompt(source, language.englishName);
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
      final parsed = _extractJson(run.stdout);
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
    } finally {
      _running.remove(ticketId);
    }
  }

  @override
  Future<Result<String>> translateText({
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
    final prompt =
        'Translate this chat message into natural ${language.englishName}. '
        'Preserve code, identifiers, URLs, emoji, @mentions and Markdown. '
        'Return ONLY the translation, with no preface or quotes.\n'
        'Message: <<<$text>>>';
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
      return Ok(out);
    } catch (e) {
      return Err(AgentFailure('OpenCode translation failed: $e', cause: e));
    } finally {
      _running.remove(key);
    }
  }

  /// Spawns the CLI and collects its output under [timeout]. `Process.run` has
  /// no deadline, so we drive the process ourselves and kill it when the timer
  /// fires — otherwise a stalled CLI hangs the caller forever.
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
    final stdoutDone = process.stdout.transform(utf8.decoder).join();
    final stderrDone = process.stderr.transform(utf8.decoder).join();
    var timedOut = false;
    final deadline = Timer(timeout, () {
      timedOut = true;
      process.kill(); // SIGTERM
    });
    final exitCode = await process.exitCode;
    deadline.cancel();
    return _CliRun(
      exitCode: exitCode,
      stdout: await stdoutDone,
      stderr: await stderrDone,
      timedOut: timedOut,
    );
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

  String _buildPrompt(TicketSource s, String languageName) =>
      'Translate this software ticket into natural, technical $languageName. '
      'Preserve code, identifiers, file paths, URLs and Markdown. '
      'Return ONLY a JSON object with keys "title" and "body".\n'
      'Title: <<<${s.title}>>>\nBody: <<<${s.body}>>>';

  Map<String, dynamic>? _extractJson(String out) {
    final start = out.indexOf('{');
    final end = out.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded = jsonDecode(out.substring(start, end + 1));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
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
