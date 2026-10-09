import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/providers.dart';
import '../di/service_locator.dart';
import '../domain/adapters/coding_agent_adapter.dart';
import '../domain/entities/agent_session.dart';
import '../domain/repositories/agent_session_repository.dart';
import '../domain/value_objects/agent_kind.dart';

/// Agent sessions for a ticket (reactive; drives the Development tab).
final agentSessionsProvider = StreamProvider.family<List<AgentSession>, String>(
  (ref, ticketId) =>
      getIt<AgentSessionRepository>().watchSessions(ticketId: ticketId),
);

/// Running agents across all tickets (sidebar Activity feed source).
final runningAgentsProvider = StreamProvider<List<AgentSession>>(
  (ref) => getIt<AgentSessionRepository>().watchRunning(),
);

/// Dispatches a ticket to a coding agent, persisting the session and streaming
/// its normalized events into the repository as it runs.
class DispatchController extends Notifier<void> {
  @override
  void build() {}

  Future<void> dispatch({
    required String ticketId,
    required AgentKind kind,
    required String workingDir,
    required String prompt,
    AgentAutonomy autonomy = AgentAutonomy.edit,
  }) async {
    final adapter = ref.read(codingAgentRegistryProvider)[kind];
    if (adapter == null) return;
    final repo = getIt<AgentSessionRepository>();
    final run = adapter.dispatch(
      DispatchTask(
        ticketId: ticketId,
        workingDir: workingDir,
        prompt: prompt,
        autonomy: autonomy,
      ),
    );
    await repo.upsertSession(run.session);
    run.events.listen((e) => repo.appendEvent(run.session.id, e));
    final finished = await run.done;
    await repo.upsertSession(finished);
  }
}

final dispatchControllerProvider = NotifierProvider<DispatchController, void>(
  DispatchController.new,
);
