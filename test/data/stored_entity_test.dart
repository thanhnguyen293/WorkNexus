import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/domain/entities/activity_event.dart';
import 'package:work_nexus/core/domain/entities/comment.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/data/local/mappers.dart';

/// A provider timestamp as the adapters produce it: UTC, with milliseconds —
/// neither of which drift keeps.
final _at = DateTime.utc(2026, 10, 14, 9, 30, 15, 123);

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'a ticket reads back equal to ticketAsStored of what was written',
    () async {
      final ticket = Ticket(
        id: 'zt:bug:1',
        accountId: 'zt',
        projectId: 'zt:p',
        providerType: ProviderType.zentao,
        externalKey: '1',
        title: 't',
        body: 'b',
        priority: Priority.high,
        status: UnifiedStatus.todo,
        providerStatus: 'active',
        sourceHash: 'h',
        labels: const ['x'],
        createdAt: _at,
        updatedAt: _at,
      );
      await db.into(db.tickets).insert(ticketToCompanion(ticket));
      final row = await db.select(db.tickets).getSingle();
      expect(ticketFromRow(row), isNot(ticket), reason: 'precision is lost');
      expect(ticketFromRow(row), ticketAsStored(ticket));
    },
  );

  test('a comment and an activity read back as their stored forms', () async {
    final comment = Comment(
      id: 'c1',
      ticketId: 'zt:bug:1',
      authorName: 'a',
      body: 'b',
      createdAt: _at,
    );
    final activity = ActivityEvent(
      id: 'e1',
      ticketId: 'zt:bug:1',
      actor: 'a',
      action: 'opened',
      at: _at,
    );
    await db.into(db.comments).insert(commentToCompanion(comment));
    await db.into(db.activities).insert(activityToCompanion(activity));
    expect(
      commentFromRow(await db.select(db.comments).getSingle()),
      commentAsStored(comment),
    );
    expect(
      activityFromRow(await db.select(db.activities).getSingle()),
      activityAsStored(activity),
    );
  });
}
