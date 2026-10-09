import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/notifications/domain/entities/zentao_notification.dart';
import 'package:work_nexus/features/notifications/domain/repositories/notification_repository.dart';
import 'package:work_nexus/features/notifications/domain/usecases/group_notifications_by_day.dart';
import 'package:work_nexus/features/notifications/domain/usecases/refresh_notifications.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

ZenTaoNotification _n(String id, DateTime? at, {bool read = false}) =>
    ZenTaoNotification(
      accountId: 'a1',
      id: id,
      summary: id,
      createdAt: at,
      read: read,
    );

void main() {
  group('GroupNotificationsByDay', () {
    const group = GroupNotificationsByDay();
    final items = [
      _n('old', DateTime(2026, 10, 5, 11)),
      _n('new', DateTime(2026, 10, 9, 11), read: true),
      _n('newer', DateTime(2026, 10, 9, 15)),
      _n('undated', null),
    ];

    test('groups by day, newest day and newest item first', () {
      final days = group(items);
      expect(days.map((d) => d.day), [
        DateTime(2026, 10, 9),
        DateTime(2026, 10, 5),
        null,
      ]);
      expect(days.first.items.map((n) => n.id), ['newer', 'new']);
    });

    test('unreadOnly leaves read ones out', () {
      final days = group(items, unreadOnly: true);
      expect(days.first.items.map((n) => n.id), ['newer']);
    });

    test('nothing in, nothing out', () {
      expect(group(const []), isEmpty);
    });
  });

  group('RefreshNotifications', () {
    late _MockNotificationRepository repository;

    setUp(() => repository = _MockNotificationRepository());

    test('refreshes every account', () async {
      when(
        () => repository.refresh(any()),
      ).thenAnswer((_) async => const Ok(null));

      final res = await RefreshNotifications(repository)(['a1', 'a2']);

      expect(res.isOk, isTrue);
      verify(() => repository.refresh('a1')).called(1);
      verify(() => repository.refresh('a2')).called(1);
    });

    test('one failing account does not stop the others', () async {
      when(
        () => repository.refresh('a1'),
      ).thenAnswer((_) async => const Err(AuthFailure('expired')));
      when(
        () => repository.refresh('a2'),
      ).thenAnswer((_) async => const Ok(null));

      final res = await RefreshNotifications(repository)(['a1', 'a2']);

      expect(res.failureOrNull, isA<AuthFailure>());
      verify(() => repository.refresh('a2')).called(1);
    });
  });
}
