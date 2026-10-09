import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/domain/entities/agent_event.dart';
import '../../../core/domain/entities/agent_session.dart';
import '../../../core/domain/value_objects/agent_kind.dart';
import '../domain/adapters/coding_agent_adapter.dart';

part 'cli_agent_adapters_runner.dart';
part 'cli_agent_adapters_codex.dart';
part 'cli_agent_adapters_claude_code.dart';
part 'cli_agent_adapters_opencode.dart';

/// Shared subprocess+JSONL machinery for the CLI-backed agents.
abstract class CliAgentAdapter implements CodingAgentAdapter {
  CliAgentAdapter({this._runner = const AgentRunner(), this.binaryOverride});

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
