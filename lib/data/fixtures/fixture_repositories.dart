import 'dart:async';

import '../../core/domain/entities/account.dart';
import '../../core/domain/entities/activity_event.dart';
import '../../core/domain/entities/agent_event.dart';
import '../../core/domain/entities/agent_session.dart';
import '../../core/domain/entities/comment.dart';
import '../../core/domain/entities/dev_link.dart';
import '../../core/domain/entities/project.dart';
import '../../core/domain/entities/ticket.dart';
import '../../core/domain/entities/translation_record.dart';
import '../../core/domain/entities/workspace.dart';
import '../../core/domain/repositories/activity_repository.dart';
import '../../core/domain/repositories/agent_session_repository.dart';
import '../../core/domain/repositories/comment_repository.dart';
import '../../core/domain/repositories/dev_link_repository.dart';
import '../../core/domain/repositories/ticket_repository.dart';
import '../../core/domain/repositories/translation_repository.dart';
import '../../core/domain/repositories/workspace_repository.dart';
import '../../core/domain/value_objects/agent_kind.dart';
import '../../core/domain/value_objects/unified_status.dart';
import '../../core/util/content_hash.dart';
import '../../features/board/domain/usecases/derive_dev_context.dart';
import 'design_seed.dart';

/// A value that emits its current state on subscribe, then every change.
class ReactiveValue<T> {
  ReactiveValue(this._value);
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

  void dispose() => _ctrl.close();
}

/// In-memory reactive store seeded from the design dataset. Shared by all
/// fixture repositories so a change (e.g. moving a ticket) re-emits everywhere.
class FixtureStore {
  FixtureStore({DateTime? now}) : _seed = SeedData.build(now: now) {
    tickets = ReactiveValue(List.of(_seed.tickets));
    translations = {
      for (final t in _seed.translations)
        t.ticketId: ReactiveValue<TranslationRecord?>(t),
    };
  }

  final SeedData _seed;
  late final ReactiveValue<List<Ticket>> tickets;
  late final Map<String, ReactiveValue<TranslationRecord?>> translations;
  final Map<String, ReactiveValue<List<Comment>>> _comments = {};

  List<Workspace> get workspaces => _seed.workspaces;
  List<Account> get accounts => _seed.accounts;
  List<Project> get projects => _seed.projects;
  Map<String, ({String title, String body})> get viByTicketId =>
      _seed.viByTicketId;

  Ticket? ticketById(String id) {
    for (final t in tickets.value) {
      if (t.id == id) return t;
    }
    return null;
  }

  ReactiveValue<TranslationRecord?> translationFor(String ticketId) =>
      translations.putIfAbsent(
        ticketId,
        () => ReactiveValue<TranslationRecord?>(null),
      );

  ReactiveValue<List<Comment>> commentsFor(String ticketId) => _comments
      .putIfAbsent(ticketId, () => ReactiveValue(_genComments(ticketId)));

  // ---- deterministic generators for detail tabs ----

  List<Comment> _genComments(String ticketId) {
    final h = intHash(ticketId);
    if (h % 2 == 1) return [];
    final t = ticketById(ticketId);
    final base = t?.updatedAt ?? DateTime.now();
    return [
      Comment(
        id: '$ticketId:c1',
        ticketId: ticketId,
        authorName: const ['Mina', 'Alex', 'Priya'][h % 3],
        body: 'Confirmed on staging — reproduces with the steps above.',
        createdAt: base.subtract(const Duration(hours: 3)),
      ),
      if (h % 4 == 0)
        Comment(
          id: '$ticketId:c2',
          ticketId: ticketId,
          authorName: 'You',
          body: 'Picking this up now, will open a PR shortly.',
          createdAt: base.subtract(const Duration(hours: 1)),
        ),
    ];
  }
}

class FixtureTicketRepository implements TicketRepository {
  FixtureTicketRepository(this._store);
  final FixtureStore _store;

  @override
  Stream<List<Ticket>> watchTickets() => _store.tickets.stream;

  @override
  Future<Ticket?> getTicket(String id) async => _store.ticketById(id);

  @override
  Future<void> upsertTickets(List<Ticket> tickets) async {
    final map = {for (final t in _store.tickets.value) t.id: t};
    for (final t in tickets) {
      map[t.id] = t;
    }
    _store.tickets.value = map.values.toList();
  }

  @override
  Future<void> moveTicket(String id, UnifiedStatus status) async {
    _store.tickets.value = [
      for (final t in _store.tickets.value)
        if (t.id == id)
          t.copyWith(status: status, providerStatus: status.name)
        else
          t,
    ];
  }
}

class FixtureWorkspaceRepository implements WorkspaceRepository {
  FixtureWorkspaceRepository(this._store);
  final FixtureStore _store;

  @override
  Stream<List<Workspace>> watchWorkspaces() => Stream.value(_store.workspaces);

  @override
  Stream<List<Account>> watchAccounts() => Stream.value(_store.accounts);

  @override
  Stream<List<Project>> watchProjects() => Stream.value(_store.projects);
}

class FixtureTranslationRepository implements TranslationRepository {
  FixtureTranslationRepository(this._store);
  final FixtureStore _store;

  @override
  Stream<TranslationRecord?> watchTranslation(String ticketId) =>
      _store.translationFor(ticketId).stream;

  @override
  Future<TranslationRecord?> getTranslation(String ticketId) async =>
      _store.translationFor(ticketId).value;

  @override
  Future<void> saveTranslation(TranslationRecord record) async {
    _store.translationFor(record.ticketId).value = record;
  }
}

class FixtureCommentRepository implements CommentRepository {
  FixtureCommentRepository(this._store);
  final FixtureStore _store;

  @override
  Stream<List<Comment>> watchComments(String ticketId) =>
      _store.commentsFor(ticketId).stream;

  @override
  Future<void> addComment(Comment comment) async {
    final r = _store.commentsFor(comment.ticketId);
    r.value = [...r.value, comment];
  }

  @override
  Future<void> upsertComments(List<Comment> comments) async {
    if (comments.isEmpty) return;
    final r = _store.commentsFor(comments.first.ticketId);
    final map = {for (final c in r.value) c.id: c};
    for (final c in comments) {
      map[c.id] = c;
    }
    r.value = map.values.toList();
  }
}

class FixtureActivityRepository implements ActivityRepository {
  FixtureActivityRepository(this._store);
  final FixtureStore _store;

  @override
  Stream<List<ActivityEvent>> watchActivity(String ticketId) {
    final t = _store.ticketById(ticketId);
    final base = t?.updatedAt ?? DateTime.now();
    final events = <ActivityEvent>[
      ActivityEvent(
        id: '$ticketId:a1',
        ticketId: ticketId,
        actor: 'reporter',
        action: 'opened',
        at: base.subtract(const Duration(days: 2)),
      ),
      ActivityEvent(
        id: '$ticketId:a2',
        ticketId: ticketId,
        actor: 'You',
        action: 'assigned',
        at: base.subtract(const Duration(days: 1)),
      ),
      ActivityEvent(
        id: '$ticketId:a3',
        ticketId: ticketId,
        actor: 'You',
        action: 'changed status to ${t?.status.name ?? 'todo'}',
        at: base.subtract(const Duration(hours: 4)),
      ),
    ];
    return Stream.value(events);
  }

  @override
  Future<void> upsertActivity(List<ActivityEvent> events) async {}
}

class FixtureDevLinkRepository implements DevLinkRepository {
  FixtureDevLinkRepository(this._store, {DeriveDevContext? derive})
    : _derive = derive ?? const DeriveDevContext();
  final FixtureStore _store;
  final DeriveDevContext _derive;

  @override
  Stream<List<DevLink>> watchDevLinks(String ticketId) {
    final t = _store.ticketById(ticketId);
    if (t == null) return Stream.value(const []);
    final ctx = _derive(t);
    final links = <DevLink>[
      if (ctx.branch != null)
        DevLink(
          id: '$ticketId:branch',
          ticketId: ticketId,
          kind: DevLinkKind.branch,
          label: ctx.branch!,
        ),
      if (ctx.pr != null)
        DevLink(
          id: '$ticketId:pr',
          ticketId: ticketId,
          kind: DevLinkKind.pullRequest,
          label: ctx.pr!,
        ),
      if (ctx.commit != null)
        DevLink(
          id: '$ticketId:commit',
          ticketId: ticketId,
          kind: DevLinkKind.commit,
          label: ctx.commit!,
        ),
    ];
    return Stream.value(links);
  }

  @override
  Future<void> upsertDevLinks(List<DevLink> links) async {}
}

class FixtureAgentSessionRepository implements AgentSessionRepository {
  final _sessions = ReactiveValue<List<AgentSession>>([]);

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
