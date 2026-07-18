import 'dart:async';

import '../../../core/domain/entities/agent_event.dart';
import '../../../core/domain/entities/agent_session.dart';
import '../../../core/domain/repositories/agent_session_repository.dart';
import '../../../core/domain/value_objects/agent_kind.dart';

/// A value that emits its current state on subscribe, then every change.
class _ReactiveValue<T> {
  _ReactiveValue(this._value);
  T _value;
  final _ctrl = StreamController<T>.broadcast();

  T get value => _value;
  set value(T v) {
    _value = v;
    _ctrl.add(v);
  }

  Stream<T> get stream async* {
    yield _value;
    yield* _ctrl.stream;
  }
}

/// In-memory agent-session store. Agent sessions are ephemeral runtime state
/// (a running/finished coding-agent dispatch), not persisted data, so they live
/// in memory rather than drift. Registered as a singleton in the service locator.
class InMemoryAgentSessionRepository implements AgentSessionRepository {
  final _sessions = _ReactiveValue<List<AgentSession>>([]);

  @override
  Stream<List<AgentSession>> watchSessions({String? ticketId}) =>
      _sessions.stream.map(
        (list) => ticketId == null
            ? list
            : list.where((s) => s.ticketId == ticketId).toList(),
      );

  @override
  Stream<List<AgentSession>> watchRunning() => _sessions.stream.map(
    (list) =>
        list.where((s) => s.status == AgentSessionStatus.running).toList(),
  );

  @override
  Future<AgentSession?> getSession(String id) async {
    for (final s in _sessions.value) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  Future<void> upsertSession(AgentSession session) async {
    final map = {for (final s in _sessions.value) s.id: s};
    map[session.id] = session;
    _sessions.value = map.values.toList();
  }

  @override
  Future<void> appendEvent(String sessionId, AgentEvent event) async {
    _sessions.value = [
      for (final s in _sessions.value)
        if (s.id == sessionId) s.copyWith(events: [...s.events, event]) else s,
    ];
  }
}
