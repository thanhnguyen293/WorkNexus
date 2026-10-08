import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../../core/domain/adapters/opencode_cli.dart';
import '../cli_agent_adapters.dart';

/// [OpenCodeCli] backed by the real `opencode` binary.
///
/// Every call is a short, read-only subcommand run on a UI path (gating
/// Translate, filling the model picker), so each one is bounded by
/// [queryTimeout] and the child is killed when it expires — a wedged CLI must
/// not wedge the app.
class OpenCodeCliRunner implements OpenCodeCli {
  const OpenCodeCliRunner([this._runner = const AgentRunner()]);

  final AgentRunner _runner;

  /// Deadline for one informational query.
  static const Duration queryTimeout = Duration(seconds: 25);

  @override
  Future<bool> hasAuthenticatedProvider() async {
    final out = await _query(const ['auth', 'list']);
    if (out == null) return false;
    final m = RegExp(r'(\d+)\s+credential').firstMatch(out);
    if (m != null) return (int.tryParse(m.group(1)!) ?? 0) > 0;
    return out.contains('●'); // fallback: a provider bullet is present
  }

  @override
  Future<List<String>> listModels() async {
    final out = await _query(const ['models']);
    if (out == null) return const <String>[];
    final ids = <String>{};
    for (final line in out.split('\n')) {
      final id = line.trim();
      // `provider/model`, one per line — ignore banners and error text.
      if (RegExp(r'^[\w.-]+/[\w.:-]+$').hasMatch(id)) ids.add(id);
    }
    return ids.toList()..sort();
  }

  /// Runs an `opencode` subcommand and returns its combined output, or null
  /// when the binary is missing, the call fails, or it outlives [queryTimeout].
  ///
  /// Driven through [Process.start] rather than [Process.run] so the deadline
  /// can actually *kill* a wedged CLI — `Process.run().timeout()` would only
  /// abandon the future and leave the child running.
  Future<String?> _query(List<String> args) async {
    final path = await _runner.resolve('opencode');
    if (path == null) return null;
    try {
      final process = await Process.start(
        path,
        args,
        runInShell: AgentRunner.needsShell,
      );
      unawaited(process.stdin.close().catchError((_) {}));
      final out = process.stdout.transform(utf8.decoder).join();
      final err = process.stderr.transform(utf8.decoder).join();
      var timedOut = false;
      final deadline = Timer(queryTimeout, () {
        timedOut = true;
        process.kill(); // SIGTERM
      });
      await process.exitCode;
      deadline.cancel();
      return timedOut ? null : '${await out}${await err}';
    } catch (_) {
      return null;
    }
  }
}
