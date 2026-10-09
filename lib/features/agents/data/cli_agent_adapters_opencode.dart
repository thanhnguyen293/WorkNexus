part of 'cli_agent_adapters.dart';

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
