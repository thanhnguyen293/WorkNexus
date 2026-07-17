import 'dart:async';

import '../../../core/domain/entities/agent_event.dart';
import '../../../core/domain/entities/agent_session.dart';
import '../../../core/domain/value_objects/agent_kind.dart';
import '../../../core/util/content_hash.dart';
import '../domain/adapters/coding_agent_adapter.dart';

/// Simulates a coding-agent run with realistic, timed progress events. Used for
/// offline demos and tests, and as the default dry-run path so dispatching never
/// spawns a real process unless the user opts in.
class MockCodingAgentAdapter implements CodingAgentAdapter {
  MockCodingAgentAdapter(
    this.kind, {
    this.speed = const Duration(milliseconds: 500),
  });

  @override
  final AgentKind kind;
  final Duration speed;

  @override
  Future<AgentHealth> healthCheck() async =>
      const AgentHealth(ok: true, version: 'mock', detail: 'dry-run');

  @override
  AgentRun dispatch(DispatchTask task) {
    final id =
        'sess-${intHash(task.ticketId ?? '')}-${DateTime.now().millisecondsSinceEpoch}';
    return _run(id, task.ticketId, task.workingDir, task.prompt);
  }

  @override
  AgentRun resume(ResumeTask task) =>
      _run(task.externalSessionId, null, task.workingDir, task.prompt);

  @override
  Future<void> cancel(String sessionId) async {}

  AgentRun _run(String id, String? ticketId, String cwd, String prompt) {
    final controller = StreamController<AgentEvent>();
    final now = DateTime.now();
    var session = AgentSession(
      id: id,
      agentKind: kind,
      status: AgentSessionStatus.running,
      startedAt: now,
      ticketId: ticketId,
      workingDir: cwd,
      externalSessionId: id,
    );

    final script = <AgentEvent>[
      AgentEvent.sessionStarted(at: now, sessionId: id, model: 'mock'),
      AgentEvent.message(
        at: now,
        role: 'assistant',
        text: 'Reading the ticket and the repo…',
      ),
      AgentEvent.toolStarted(at: now, toolName: 'Grep'),
      AgentEvent.toolCompleted(at: now, toolName: 'Grep', ok: true),
      AgentEvent.message(
        at: now,
        role: 'assistant',
        text: 'Applying a fix to the affected files.',
      ),
      AgentEvent.fileChanged(
        at: now,
        path: 'lib/example.dart',
        changeType: FileChangeType.modified,
      ),
      AgentEvent.toolStarted(at: now, toolName: 'Edit'),
      AgentEvent.toolCompleted(at: now, toolName: 'Edit', ok: true),
      AgentEvent.result(
        at: now,
        summary:
            '(dry-run) ${kind.displayName} would implement: '
            '${prompt.length > 60 ? '${prompt.substring(0, 60)}…' : prompt}',
        costUsd: 0,
      ),
    ];

    () async {
      final events = <AgentEvent>[];
      for (final e in script) {
        await Future.delayed(speed);
        events.add(e);
        if (!controller.isClosed) controller.add(e);
      }
      session = session.copyWith(
        status: AgentSessionStatus.succeeded,
        finishedAt: DateTime.now(),
        resultSummary: (script.last as AgentResult).summary,
        changedFiles: const ['lib/example.dart'],
        events: events,
      );
      await controller.close();
    }();

    return AgentRun(
      session: session,
      events: controller.stream,
      done: controller.done.then((_) => session),
    );
  }
}
