import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/notifications/data/datasources/notification_local_datasource.dart';
import 'package:work_nexus/features/notifications/data/repositories/zentao_notification_repository.dart';
import 'package:work_nexus/features/notifications/domain/entities/zentao_notification.dart';

Map<String, dynamic> _message(String id, {bool read = false}) => {
  'id': id,
  'status': read ? 'read' : 'sended',
  'createdDate': '2026-10-09 11:0$id:00',
  'data': 'Message $id',
};

void main() {
  late AppDatabase db;
  late Map<String, List<Map<String, dynamic>>> server;
  late List<String> actions;
  late Result<void> actionResult;
  late ZenTaoNotificationRepository repository;

  Future<List<ZenTaoNotification>> stored() => repository.watchAll().first;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    server = {
      'a1': [_message('1'), _message('2', read: true)],
      'a2': [_message('3')],
    };
    actions = [];
    actionResult = const Ok(null);
    repository = ZenTaoNotificationRepository(
      local: NotificationLocalDatasource(db),
      fetch: (accountId) async => Ok({
        'allMessages': {'day': server[accountId]},
      }),
      run: (accountId, action) async {
        actions.add('$accountId $action');
        return actionResult;
      },
    );
  });

  tearDown(() => db.close());

  test('refresh stores an account and replaces only its rows', () async {
    await repository.refresh('a1');
    await repository.refresh('a2');
    server['a1'] = [_message('4')];

    await repository.refresh('a1');

    final ids = (await stored()).map((n) => '${n.accountId}:${n.id}');
    expect(ids, unorderedEquals(['a1:4', 'a2:3']));
  });

  test('markRead updates the store and runs the ZenTao action', () async {
    await repository.refresh('a1');

    expect((await repository.markRead('a1', id: '1')).isOk, isTrue);

    expect(actions, ['a1 ajaxMarkRead-1']);
    expect((await stored()).every((n) => n.read), isTrue);
  });

  test('markRead without an id marks the whole account', () async {
    await repository.refresh('a1');
    await repository.refresh('a2');

    await repository.markRead('a1');

    expect(actions, ['a1 ajaxMarkRead-all']);
    final unread = (await stored()).where((n) => !n.read).map((n) => n.id);
    expect(unread, ['3']);
  });

  test('deleteRead removes only read notifications', () async {
    await repository.refresh('a1');

    await repository.deleteRead('a1');

    expect(actions, ['a1 ajaxDelete-allread']);
    expect((await stored()).map((n) => n.id), ['1']);
  });

  test('a refused action is reported and the server list restored', () async {
    await repository.refresh('a1');
    actionResult = const Err(NetworkFailure('offline'));

    final res = await repository.delete('a1', '1');

    expect(res.failureOrNull, isA<NetworkFailure>());
    expect((await stored()).map((n) => n.id), unorderedEquals(['1', '2']));
  });
}
