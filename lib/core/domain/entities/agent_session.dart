import 'package:freezed_annotation/freezed_annotation.dart';

import '../value_objects/agent_kind.dart';
import 'agent_event.dart';

part 'agent_session.freezed.dart';

/// A single run of a coding agent against a ticket. [events] is the append-only
/// normalized progress log; [diff]/[changedFiles] are computed from `git` after
/// the run completes (adapters don't emit a reliable unified diff).
@freezed
abstract class AgentSession with _$AgentSession {
  const factory AgentSession({
    required String id,
    required AgentKind agentKind,
    required AgentSessionStatus status,
    required DateTime startedAt,
    String? ticketId,
    String? workingDir,
    String? externalSessionId,
    DateTime? finishedAt,
    String? resultSummary,
    @Default(<String>[]) List<String> changedFiles,
    String? diff,
    double? costUsd,
    String? error,
    @Default(<AgentEvent>[]) List<AgentEvent> events,
  }) = _AgentSession;
}
