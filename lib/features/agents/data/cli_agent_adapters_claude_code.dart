part of 'cli_agent_adapters.dart';

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
