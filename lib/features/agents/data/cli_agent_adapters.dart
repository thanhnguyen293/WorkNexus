import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/domain/entities/agent_event.dart';
import '../../../core/domain/entities/agent_session.dart';
import '../../../core/domain/value_objects/agent_kind.dart';
import '../domain/adapters/coding_agent_adapter.dart';

/// Resolves CLI binaries (GUI apps on macOS don't inherit the shell PATH) and
/// spawns them. The resolved path can be overridden per agent in Settings.
class AgentRunner {
  const AgentRunner();

  /// Whether spawned CLIs must go through a shell. On Windows the binary may be
  /// a `.cmd`/`.bat` shim (e.g. npm-installed `opencode`), which `CreateProcess`
  /// cannot launch directly — it needs `%COMSPEC% /c`.
  static bool get needsShell => Platform.isWindows;

  Future<String?> resolve(String name, {String? override}) async {
    if (override != null && override.trim().isNotEmpty) return override.trim();
    return Platform.isWindows ? _resolveWindows(name) : _resolveUnix(name);
  }

  /// macOS/Linux: a GUI launch omits the interactive-shell PATH (nvm, asdf,
  /// Homebrew, `~/.local/bin`, …), so ask a login shell, then fall back to a
  /// direct PATH scan for non-interactive shells.
  Future<String?> _resolveUnix(String name) async {
    final shell = Platform.environment['SHELL'] ?? '/bin/zsh';
    try {
      final res = await Process.run(shell, ['-lic', 'command -v $name']);
      final hit = res.stdout
          .toString()
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.startsWith('/'))
          .toList();
      if (hit.isNotEmpty) return hit.last;
    } catch (_) {}
    return _scanPath(name, const ['']);
  }

  /// Windows: the app already inherits the user/system PATH, so use `where`
  /// (which honors PATHEXT), then fall back to a manual PATH+PATHEXT scan.
  Future<String?> _resolveWindows(String name) async {
    try {
      final res = await Process.run('where', [name]);
      if (res.exitCode == 0) {
        final hit = res.stdout
            .toString()
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        if (hit.isNotEmpty) return hit.first;
      }
    } catch (_) {}
    final exts = (Platform.environment['PATHEXT'] ?? '.COM;.EXE;.BAT;.CMD')
        .split(';')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return _scanPath(name, [...exts, '']);
  }

  /// Walks `PATH` looking for `name` with any of [exts] (in order).
  String? _scanPath(String name, List<String> exts) {
    final entries = (Platform.environment['PATH'] ?? '')
        .split(Platform.isWindows ? ';' : ':')
        .map((d) => d.trim())
        .where((d) => d.isNotEmpty);
    for (final dir in entries) {
      for (final ext in exts) {
        final candidate = File('$dir${Platform.pathSeparator}$name$ext');
        if (candidate.existsSync()) return candidate.path;
      }
    }
    return null;
  }

  /// Whether OpenCode has at least one authenticated provider
  /// (`opencode auth list`). Used to gate translation so we don't run a headless
  /// prompt against an unauthenticated CLI.
  Future<bool> hasOpenCodeAuth({String? override}) async {
    final path = await resolve('opencode', override: override);
    if (path == null) return false;
    try {
      final res = await Process.run(path, [
        'auth',
        'list',
      ], runInShell: needsShell);
      final out = '${res.stdout}${res.stderr}';
      final m = RegExp(r'(\d+)\s+credential').firstMatch(out);
      if (m != null) return (int.tryParse(m.group(1)!) ?? 0) > 0;
      return out.contains('●'); // fallback: a provider bullet is present
    } catch (_) {
      return false;
    }
  }

  Future<Process> start(
    String executable,
    List<String> args, {
    required String workingDir,
    Map<String, String>? extraEnv,
  }) {
    return Process.start(
      executable,
      args,
      workingDirectory: workingDir,
      environment: {...Platform.environment, ...?extraEnv},
      runInShell: needsShell,
    );
  }
}

/// Shared subprocess+JSONL machinery for the CLI-backed agents.
abstract class CliAgentAdapter implements CodingAgentAdapter {
  CliAgentAdapter({
    AgentRunner runner = const AgentRunner(),
    this.binaryOverride,
  }) : _runner = runner;

  final AgentRunner _runner;
  final String? binaryOverride;
  final Map<String, Process> _procs = {};

  /// The CLI executable name (resolved on PATH).
  String get binaryName => kind.cliName;

  /// Build the argument list for a dispatch.
  List<String> buildArgs(DispatchTask task);

  /// Translate one decoded JSONL object into a normalized event (or null).
  AgentEvent? parseLine(Map<String, dynamic> json, DateTime at);

  @override
  Future<AgentHealth> healthCheck() async {
    final path = await _runner.resolve(binaryName, override: binaryOverride);
    return AgentHealth(
      ok: path != null,
      detail: path ?? '$binaryName not found on PATH',
    );
  }

  @override
  AgentRun dispatch(DispatchTask task) =>
      _run(task, task.workingDir, task.ticketId);

  @override
  AgentRun resume(ResumeTask task) => _run(
    DispatchTask(workingDir: task.workingDir, prompt: task.prompt),
    task.workingDir,
    null,
  );

  @override
  Future<void> cancel(String sessionId) async {
    _procs.remove(sessionId)?.kill();
  }

  AgentRun _run(DispatchTask task, String cwd, String? ticketId) {
    final controller = StreamController<AgentEvent>();
    final id = 'sess-${DateTime.now().microsecondsSinceEpoch}';
    final events = <AgentEvent>[];
    var session = AgentSession(
      id: id,
      agentKind: kind,
      status: AgentSessionStatus.running,
      startedAt: DateTime.now(),
      ticketId: ticketId,
      workingDir: cwd,
    );

    void emit(AgentEvent e) {
      events.add(e);
      if (!controller.isClosed) controller.add(e);
    }

    Future<void> drive() async {
      final path = await _runner.resolve(binaryName, override: binaryOverride);
      if (path == null) {
        emit(
          AgentEvent.error(
            at: DateTime.now(),
            message: '$binaryName not found on PATH',
            fatal: true,
          ),
        );
        session = session.copyWith(
          status: AgentSessionStatus.failed,
          finishedAt: DateTime.now(),
          error: '$binaryName not found',
        );
        await controller.close();
        return;
      }
      try {
        final proc = await _runner.start(
          path,
          buildArgs(task),
          workingDir: cwd,
        );
        _procs[id] = proc;
        proc.stderr
            .transform(utf8.decoder)
            .listen((_) {}); // drain to avoid deadlock
        await for (final line
            in proc.stdout
                .transform(utf8.decoder)
                .transform(const LineSplitter())) {
          if (line.trim().isEmpty) continue;
          try {
            final decoded = jsonDecode(line);
            if (decoded is Map<String, dynamic>) {
              final e = parseLine(decoded, DateTime.now());
              if (e != null) emit(e);
            }
          } catch (_) {
            // Non-JSON progress line; ignore.
          }
        }
        final exit = await proc.exitCode;
        _procs.remove(id);
        final hasResult = events.any((e) => e is AgentResult);
        if (!hasResult) {
          emit(
            AgentEvent.result(
              at: DateTime.now(),
              summary: 'Finished (exit $exit)',
              isError: exit != 0,
            ),
          );
        }
        session = session.copyWith(
          status: exit == 0
              ? AgentSessionStatus.succeeded
              : AgentSessionStatus.failed,
          finishedAt: DateTime.now(),
          resultSummary: events.whereType<AgentResult>().isEmpty
              ? null
              : events.whereType<AgentResult>().last.summary,
          events: events,
        );
      } catch (e) {
        emit(AgentEvent.error(at: DateTime.now(), message: '$e', fatal: true));
        session = session.copyWith(
          status: AgentSessionStatus.failed,
          finishedAt: DateTime.now(),
          error: '$e',
        );
      } finally {
        if (!controller.isClosed) await controller.close();
      }
    }

    drive();
    return AgentRun(
      session: session,
      events: controller.stream,
      done: controller.done.then((_) => session),
    );
  }

  String sandboxFor(AgentAutonomy a) => switch (a) {
    AgentAutonomy.readOnly => 'read-only',
    AgentAutonomy.edit => 'workspace-write',
    AgentAutonomy.full => 'danger-full-access',
  };
}

/// OpenAI Codex: `codex exec --json`.
class CodexAdapter extends CliAgentAdapter {
  CodexAdapter({super.runner, super.binaryOverride});

  @override
  AgentKind get kind => AgentKind.codex;

  @override
  List<String> buildArgs(DispatchTask task) => [
    'exec',
    '--json',
    '--sandbox',
    sandboxFor(task.autonomy),
    '-C',
    task.workingDir,
    '--skip-git-repo-check',
    if (task.model != null) ...['-m', task.model!],
    task.prompt,
  ];

  @override
  AgentEvent? parseLine(Map<String, dynamic> json, DateTime at) {
    switch (json['type']) {
      case 'thread.started':
        return AgentEvent.sessionStarted(
          at: at,
          sessionId: json['thread_id']?.toString(),
        );
      case 'item.completed':
        final item = json['item'];
        if (item is Map) {
          switch (item['type']) {
            case 'agent_message':
              return AgentEvent.message(
                at: at,
                role: 'assistant',
                text: item['text']?.toString() ?? '',
              );
            case 'command_execution':
              return AgentEvent.toolCompleted(
                at: at,
                toolName: 'command',
                ok: true,
              );
            case 'file_change':
              return AgentEvent.fileChanged(
                at: at,
                path: item['path']?.toString() ?? '',
                changeType: FileChangeType.modified,
              );
          }
        }
        return null;
      case 'turn.completed':
        final usage = json['usage'];
        return AgentEvent.result(
          at: at,
          summary: 'Turn completed',
          costUsd: usage is Map ? null : null,
        );
      default:
        return null;
    }
  }
}

/// Claude Code: `claude -p --output-format stream-json --verbose`.
class ClaudeCodeAdapter extends CliAgentAdapter {
  ClaudeCodeAdapter({super.runner, super.binaryOverride});

  @override
  AgentKind get kind => AgentKind.claudeCode;

  @override
  List<String> buildArgs(DispatchTask task) => [
    '-p',
    task.prompt,
    '--output-format',
    'stream-json',
    '--verbose',
    '--permission-mode',
    switch (task.autonomy) {
      AgentAutonomy.readOnly => 'plan',
      AgentAutonomy.edit => 'acceptEdits',
      AgentAutonomy.full => 'bypassPermissions',
    },
    if (task.model != null) ...['--model', task.model!],
  ];

  @override
  AgentEvent? parseLine(Map<String, dynamic> json, DateTime at) {
    switch (json['type']) {
      case 'system':
        if (json['subtype'] == 'init') {
          return AgentEvent.sessionStarted(
            at: at,
            sessionId: json['session_id']?.toString(),
            model: json['model']?.toString(),
          );
        }
        return null;
      case 'assistant':
        final msg = json['message'];
        final text = msg is Map ? _claudeText(msg['content']) : '';
        return text.isEmpty
            ? null
            : AgentEvent.message(at: at, role: 'assistant', text: text);
      case 'result':
        return AgentEvent.result(
          at: at,
          summary: json['result']?.toString() ?? 'Done',
          isError: json['is_error'] == true,
          costUsd: (json['total_cost_usd'] as num?)?.toDouble(),
        );
      default:
        return null;
    }
  }

  String _claudeText(Object? content) {
    if (content is String) return content;
    if (content is List) {
      return content
          .whereType<Map<String, dynamic>>()
          .where((b) => b['type'] == 'text')
          .map((b) => b['text']?.toString() ?? '')
          .join();
    }
    return '';
  }
}

/// OpenCode: `opencode run --format json` (one-shot subprocess path).
class OpenCodeCliAdapter extends CliAgentAdapter {
  OpenCodeCliAdapter({super.runner, super.binaryOverride});

  @override
  AgentKind get kind => AgentKind.opencode;

  @override
  List<String> buildArgs(DispatchTask task) => [
    'run',
    '--format',
    'json',
    if (task.model != null) ...['-m', task.model!],
    task.prompt,
  ];

  @override
  AgentEvent? parseLine(Map<String, dynamic> json, DateTime at) {
    final type = json['type']?.toString() ?? '';
    if (type.contains('message') && json['text'] != null) {
      return AgentEvent.message(
        at: at,
        role: 'assistant',
        text: json['text'].toString(),
      );
    }
    return null;
  }
}
