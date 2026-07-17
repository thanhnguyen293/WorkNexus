import '../entities/agent_event.dart';
import '../entities/agent_session.dart';

/// Persistence for coding-agent runs and their append-only event logs.
abstract class AgentSessionRepository {
  /// Sessions, optionally scoped to a ticket. Ordered newest-first.
  Stream<List<AgentSession>> watchSessions({String? ticketId});

  /// Currently-running sessions (drives the sidebar Activity feed).
  Stream<List<AgentSession>> watchRunning();

  Future<AgentSession?> getSession(String id);
  Future<void> upsertSession(AgentSession session);

  /// Append one normalized progress event to a session's log.
  Future<void> appendEvent(String sessionId, AgentEvent event);
}
