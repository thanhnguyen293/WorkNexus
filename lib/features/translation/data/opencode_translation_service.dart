import 'dart:convert';
import 'dart:io';

import '../../../core/domain/entities/translation_record.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/util/content_hash.dart';
import '../../agents/data/cli_agent_adapters.dart';
import '../domain/adapters/translation_service.dart';

/// Real OpenCode-backed translation via the `opencode run` CLI. Registered as
/// the [TranslationService] in the GetIt service locator (`configureDependencies`).
///
/// It uses OpenCode's **own** authentication (`opencode auth login`) and the
/// configured default model, so translations run through your normal provider
/// (e.g. OpenCode Go) and show up in its usage/quota. Pass [model] to pin a
/// specific model (e.g. `opencode-go/deepseek-v4-pro`); leave it null to use
/// whatever your OpenCode config defaults to. We deliberately do NOT inject a
/// provider API key into the environment — that would reroute the call onto a
/// different provider and bypass your OpenCode usage tracking.
class OpenCodeTranslationService implements TranslationService {
  OpenCodeTranslationService({
    AgentRunner runner = const AgentRunner(),
    this.model,
    this.workingDir,
    this.binaryOverride,
  }) : _runner = runner;

  final AgentRunner _runner;

  /// Explicit model id (`provider/model`). Null ⇒ OpenCode's configured default.
  final String? model;

  /// Directory the run is executed in (session grouping). Null ⇒ the user's home.
  final String? workingDir;
  final String? binaryOverride;

  static const _templateVersion = 'oc-v1';

  @override
  String contentHash(TicketSource source) =>
      contentHash2(source.title, source.body);

  @override
  Future<Result<TranslationRecord>> translate({
    required String ticketId,
    required TicketSource source,
    required String sourceHash,
  }) async {
    final path = await _runner.resolve('opencode', override: binaryOverride);
    if (path == null) {
      return const Err(AgentFailure('opencode not found on PATH'));
    }
    final cwd =
        workingDir ?? Platform.environment['HOME'] ?? Directory.current.path;
    final prompt = _buildPrompt(source);
    try {
      final res = await Process.run(
        path,
        [
          'run',
          if (model != null) ...['-m', model!],
          prompt,
        ],
        environment: Platform.environment,
        workingDirectory: cwd,
      );
      if (res.exitCode != 0) {
        final err = res.stderr.toString().trim();
        return Err(
          AgentFailure(
            'OpenCode exited ${res.exitCode}${err.isEmpty ? '' : ': $err'}',
          ),
        );
      }
      final parsed = _extractJson(res.stdout.toString());
      if (parsed == null) {
        return const Err(ParseFailure('Could not parse OpenCode translation'));
      }
      return Ok(
        TranslationRecord(
          ticketId: ticketId,
          sourceHash: sourceHash,
          targetLang: 'vi',
          translatedTitle: parsed['vi_title']?.toString() ?? source.title,
          translatedBody: parsed['vi_body']?.toString() ?? source.body,
          model: model ?? 'opencode/default',
          templateVersion: _templateVersion,
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      return Err(AgentFailure('OpenCode translation failed: $e', cause: e));
    }
  }

  String _buildPrompt(TicketSource s) =>
      'Translate this software ticket into natural, technical Vietnamese. '
      'Preserve code, identifiers, file paths, URLs and Markdown. '
      'Return ONLY a JSON object with keys "vi_title" and "vi_body".\n'
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

/// Shared hashing so the service and cache agree on the content hash.
String contentHash2(String title, String body) => contentHash(title, body);
