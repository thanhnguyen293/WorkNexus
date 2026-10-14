import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/entities/comment.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/data/local/mappers.dart';
import 'package:work_nexus/features/sync/data/ticket_store.dart';

const _account = Account(
  id: 'zt',
  workspaceId: 'ws',
  providerType: ProviderType.zentao,
  handle: 'me',
);

Ticket _t(String id, {String title = 't', List<String> labels = const []}) =>
    Ticket(
      id: 'zt:bug:$id',
      accountId: 'zt',
      projectId: 'zt:p',
      providerType: ProviderType.zentao,
      externalKey: id,
      title: title,
      body: 'b',
      priority: Priority.medium,
      status: UnifiedStatus.todo,
      providerStatus: 'active',
      sourceHash: 'h',
      labels: labels,
      updatedAt: DateTime.utc(2026, 10, 14, 9, 30, 15, 123),
      providerEntity: ZenTaoBugEntity(
        severity: 2,
        openedDate: DateTime.utc(2026, 10, 1, 8, 0, 0, 250),
      ),
    );

void main() {
  late AppDatabase db;
  late TicketStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = TicketStore(db);
  });
  tearDown(() => db.close());

  /// How many times the ticket watch emits while [action] runs: one per
  /// write to the table, so zero means nothing was written.
  Future<int> ticketEmissions(Future<void> Function() action) async {
    var count = 0;
    final sub = db.watchTickets().listen((_) => count++);
    addTearDown(sub.cancel);
    await pumpEventQueue();
    final before = count;
    await action();
    await pumpEventQueue();
    return count - before;
  }

  group('writeSynced', () {
    test('a page that brings nothing new writes nothing', () async {
      await store.writeSynced(_account, [_t('1'), _t('2')]);
      expect(
        await ticketEmissions(
          () => store.writeSynced(_account, [_t('1'), _t('2')]),
        ),
        0,
      );
      expect(
        await ticketEmissions(
          () => store.writeSynced(_account, [_t('1'), _t('2', title: 'new')]),
        ),
        1,
      );
      final rows = await db.select(db.tickets).get();
      expect(
        {for (final r in rows) r.id: r.title},
        {'zt:bug:1': 't', 'zt:bug:2': 'new'},
      );
    });

    test('carries the stored board-membership labels forward', () async {
      await store.writeSynced(_account, [
        _t('1', labels: const ['zentao-product:7', 'real']),
      ]);
      await store.writeSynced(_account, [
        _t('1', labels: const ['zentao-execution:3']),
      ]);
      final row = await db.select(db.tickets).getSingle();
      expect(
        decodeLabels(row.labelsJson),
        unorderedEquals(['zentao-execution:3', 'zentao-product:7']),
      );
    });

    test('stores the account and the derived projects once', () async {
      await store.writeSynced(_account, [_t('1')]);
      final projects = await db.select(db.projects).get();
      expect(projects.single.name, 'p');
      expect((await db.select(db.accounts).get()).single.id, 'zt');
    });
  });

  group('writeIfChanged', () {
    test('replaces an optimistic row with the server state', () async {
      final original = _t('1');
      await store.writeSynced(_account, [original]);
      // An action's optimistic guess lands first; the server then reports
      // the action did not take, i.e. the state the caller started from.
      await db
          .into(db.tickets)
          .insertOnConflictUpdate(
            ticketToCompanion(original.copyWith(providerStatus: 'resolved')),
          );
      await store.writeIfChanged(original);
      final row = await db.select(db.tickets).getSingle();
      expect(row.providerStatus, 'active');
    });

    test('an unchanged ticket is not rewritten', () async {
      final ticket = _t('1');
      await store.writeSynced(_account, [ticket]);
      expect(await ticketEmissions(() => store.writeIfChanged(ticket)), 0);
    });
  });

  group('replaceProviderComments', () {
    final a = Comment(
      id: 'c1',
      ticketId: 'zt:bug:1',
      authorName: 'a',
      body: 'first',
      createdAt: DateTime.utc(2026, 10, 14, 9, 0, 0, 500),
    );
    final note = Comment(
      id: 'n1',
      ticketId: 'zt:bug:1',
      authorName: 'me',
      body: 'internal',
      createdAt: DateTime.utc(2026, 10, 14, 9, 5),
      origin: CommentOrigin.internalNote,
    );

    Future<int> commentEmissions(Future<void> Function() action) async {
      var count = 0;
      final sub = db.watchComments('zt:bug:1').listen((_) => count++);
      addTearDown(sub.cancel);
      await pumpEventQueue();
      final before = count;
      await action();
      await pumpEventQueue();
      return count - before;
    }

    test('an unchanged set is left alone, a changed one replaced', () async {
      await db.into(db.comments).insert(commentToCompanion(note));
      await store.replaceProviderComments('zt:bug:1', [a]);
      expect(
        await commentEmissions(
          () => store.replaceProviderComments('zt:bug:1', [a]),
        ),
        0,
      );
      await store.replaceProviderComments('zt:bug:1', [
        a.copyWith(body: 'edited'),
      ]);
      final rows = await db.select(db.comments).get();
      expect(
        {for (final r in rows) r.id: r.body},
        {'c1': 'edited', 'n1': 'internal'},
      );
    });
  });
}
