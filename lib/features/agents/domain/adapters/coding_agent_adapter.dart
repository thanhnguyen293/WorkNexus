import '../../../../core/domain/entities/agent_event.dart';
import '../../../../core/domain/entities/agent_session.dart';
import '../../../../core/domain/value_objects/agent_kind.dart';

/// A request to run a coding agent against a ticket in a working directory.
class DispatchTask {
  const DispatchTask({
    required this.workingDir,
    required this.prompt,
    this.ticketId,
    this.systemPromptAppend,
    this.model,
    this.maxTurns,
    this.autonomy = AgentAutonomy.edit,
    this.allowedTools,
  });

  final String workingDir;
  final String prompt;
  final String? ticketId;
  final String? systemPromptAppend;
  final String? model;
  final int? maxTurns;
  final AgentAutonomy autonomy;
  final List<String>? allowedTools;
}

/// Continue a prior agent session.
class ResumeTask {
  const ResumeTask({
    required this.externalSessionId,
    required this.workingDir,
    required this.prompt,
    this.fork = false,
  });

  final String externalSessionId;
  final String workingDir;
  final String prompt;
  final bool fork;
}

/// A live agent run: the initial session snapshot, a normalized event stream,
/// and a future that resolves to the final session (succeeded/failed).
class AgentRun {
  const AgentRun({
    required this.session,
    required this.events,
    required this.done,
  });

  final AgentSession session;
  final Stream<AgentEvent> events;
  final Future<AgentSession> done;
}

class AgentHealth {
  const AgentHealth({required this.ok, this.version, this.detail});

  final bool ok;
  final String? version;
  final String? detail;
}

/// One interface over three transports (Claude SDK/CLI, Codex JSONL, OpenCode
/// SSE). Implementations normalize native events into [AgentEvent]s.
abstract class CodingAgentAdapter {
  AgentKind get kind;

  Future<AgentHealth> healthCheck();

  AgentRun dispatch(DispatchTask task);

  AgentRun resume(ResumeTask task);

  Future<void> cancel(String sessionId);
}
