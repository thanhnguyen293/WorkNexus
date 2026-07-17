import 'package:freezed_annotation/freezed_annotation.dart';

part 'agent_event.freezed.dart';

enum FileChangeType { created, modified, deleted }

/// A normalized progress event emitted by every [CodingAgentAdapter],
/// regardless of the underlying transport (Claude SDK / Codex JSONL / OpenCode
/// SSE). Adapters map their native events onto this union.
@freezed
sealed class AgentEvent with _$AgentEvent {
  const factory AgentEvent.sessionStarted({
    required DateTime at,
    String? sessionId,
    String? model,
  }) = AgentSessionStarted;

  const factory AgentEvent.textDelta({
    required DateTime at,
    required String text,
  }) = AgentTextDelta;

  const factory AgentEvent.message({
    required DateTime at,
    required String role, // 'assistant' | 'user'
    required String text,
  }) = AgentMessage;

  const factory AgentEvent.toolStarted({
    required DateTime at,
    required String toolName,
    String? toolCallId,
  }) = AgentToolStarted;

  const factory AgentEvent.toolCompleted({
    required DateTime at,
    required String toolName,
    required bool ok,
    String? toolCallId,
  }) = AgentToolCompleted;

  const factory AgentEvent.fileChanged({
    required DateTime at,
    required String path,
    required FileChangeType changeType,
  }) = AgentFileChanged;

  const factory AgentEvent.planUpdated({
    required DateTime at,
    required List<String> steps,
  }) = AgentPlanUpdated;

  const factory AgentEvent.retry({
    required DateTime at,
    required int attempt,
    String? reason,
  }) = AgentRetry;

  const factory AgentEvent.error({
    required DateTime at,
    required String message,
    @Default(false) bool fatal,
  }) = AgentErrorEvent;

  const factory AgentEvent.result({
    required DateTime at,
    required String summary,
    @Default(false) bool isError,
    double? costUsd,
  }) = AgentResult;
}
