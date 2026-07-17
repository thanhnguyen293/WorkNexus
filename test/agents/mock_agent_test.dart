import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/agent_event.dart';
import 'package:work_nexus/core/domain/value_objects/agent_kind.dart';
import 'package:work_nexus/features/agents/data/mock_coding_agent_adapter.dart';
import 'package:work_nexus/features/agents/domain/adapters/coding_agent_adapter.dart';

void main() {
  test('mock dispatch streams events and finishes succeeded', () async {
    final adapter = MockCodingAgentAdapter(
      AgentKind.codex,
      speed: const Duration(milliseconds: 1),
    );
    final run = adapter.dispatch(
      const DispatchTask(
        ticketId: 't1',
        workingDir: '/tmp',
        prompt: 'Fix the bug',
      ),
    );

    final events = await run.events.toList();
    final session = await run.done;

    expect(events.first, isA<AgentSessionStarted>());
    expect(events.whereType<AgentResult>(), isNotEmpty);
    expect(session.status, AgentSessionStatus.succeeded);
    expect(session.resultSummary, isNotNull);
    expect(session.events, isNotEmpty);
  });
}
