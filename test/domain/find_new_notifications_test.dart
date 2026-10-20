import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/notifications/domain/entities/zentao_notification.dart';
import 'package:work_nexus/features/notifications/domain/usecases/find_new_notifications.dart';

ZenTaoNotification _n(
  String id, {
  String account = 'zt',
  bool read = false,
  int minute = 0,
}) => ZenTaoNotification(
  accountId: account,
  id: id,
  summary: 'JunNg assigned Bug',
  read: read,
  createdAt: DateTime(2026, 10, 20, 10, minute),
);

/// What a refresh brought in, to raise on the desktop.
void main() {
  const find = FindNewNotifications();

  test('the first list is the backlog, not news', () {
    final r = find((seen: null, current: [_n('1'), _n('2')]));
    expect(r.fresh, isEmpty);
    expect(r.seen, {'zt:1', 'zt:2'});
  });

  test('raises the unread ones not seen before, newest first', () {
    final r = find((
      seen: {'zt:1'},
      current: [_n('1'), _n('2', minute: 5), _n('3', minute: 9)],
    ));
    expect(r.fresh.map((n) => n.id), ['3', '2']);
    expect(r.seen, {'zt:1', 'zt:2', 'zt:3'});
  });

  test('not one already read elsewhere', () {
    final r = find((seen: {'zt:1'}, current: [_n('1'), _n('2', read: true)]));
    expect(r.fresh, isEmpty);
  });

  test('tells accounts apart', () {
    final r = find((
      seen: {'zt:1', 'other:9'},
      current: [_n('1', account: 'other')],
    ));
    expect(r.fresh.single.accountId, 'other');
  });

  // The first list is the local database: empty on a fresh install (or for
  // an account just added) until the first fetch fills it.
  test("an account's first notifications are its backlog, not news", () {
    final empty = find((seen: null, current: const []));
    final fetched = find((seen: empty.seen, current: [_n('1'), _n('2')]));
    expect(fetched.fresh, isEmpty);
    final added = find((
      seen: fetched.seen,
      current: [
        _n('1'),
        _n('2'),
        _n('7', account: 'new'),
      ],
    ));
    expect(added.fresh, isEmpty);
    final later = find((
      seen: added.seen,
      current: [
        _n('1'),
        _n('2'),
        _n('7', account: 'new'),
        _n('3'),
      ],
    ));
    expect(later.fresh.single.id, '3');
  });

  test('one that dropped off the list and came back is not news', () {
    final afterGap = find((seen: {'zt:1', 'zt:2'}, current: [_n('1')]));
    final back = find((seen: afterGap.seen, current: [_n('1'), _n('2')]));
    expect(back.fresh, isEmpty);
  });
}
