part of 'cli_agent_adapters.dart';

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
