import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/notifications/data/mappers/zentao_notification_mapper.dart';

/// Shaped like the view of `message-ajaxGetDropmenu-all`: by day, the link
/// already rewritten to `data-url` by ZenTao, ids and dates as strings.
final _view = <String, dynamic>{
  'unreadCount': 2,
  'allMessages': {
    '2026-10-09': [
      {
        'id': '301',
        'status': 'sended',
        'createdDate': '2026-10-09 11:06:12',
        'data':
            "JunNg-VN-Flutter assigned Bug <a data-url='https://zt.example/zentao/bug-view-6492.html' href='###' onclick='clickMessage(this)'>[#6492::[Discover] Feed: video &amp; autoplay]</a>",
      },
    ],
    '2026-10-06': [
      {
        'id': 290,
        'status': 'read',
        'createdDate': '2026-10-06 10:45:00',
        'data':
            "Luci finished Task <a href='https://zt.example/zentao/index.php?m=task&amp;f=view&amp;taskID=12492'>[#12492::Livestream share]</a>",
      },
      {'id': '289', 'status': 'wait', 'data': 'Plain text, no link'},
      {'id': '', 'data': 'no id — skipped'},
    ],
  },
};

void main() {
  final items = zenTaoNotificationsFromView(_view, accountId: 'a1');

  test('reads every message with an id', () {
    expect(items.map((n) => n.id), ['301', '290', '289']);
    expect(items.every((n) => n.accountId == 'a1'), isTrue);
  });

  test('splits the summary from the linked object', () {
    final n = items.first;
    expect(n.summary, 'JunNg-VN-Flutter assigned Bug');
    expect(n.objectType, 'bug');
    expect(n.objectId, '6492');
    expect(n.objectTitle, '[Discover] Feed: video & autoplay');
    expect(n.url, 'https://zt.example/zentao/bug-view-6492.html');
    expect(n.read, isFalse);
    expect(n.createdAt, DateTime(2026, 10, 9, 11, 6, 12));
  });

  test('reads the object from a query-style link and the read status', () {
    final n = items[1];
    expect(n.objectType, 'task');
    expect(n.objectId, '12492');
    expect(n.objectTitle, 'Livestream share');
    expect(n.read, isTrue);
  });

  test('a message without a link keeps its whole text', () {
    final n = items[2];
    expect(n.summary, 'Plain text, no link');
    expect(n.objectType, isNull);
    expect(n.url, isNull);
    expect(n.createdAt, isNull);
  });

  test('a view without messages is empty', () {
    expect(zenTaoNotificationsFromView({}, accountId: 'a1'), isEmpty);
    expect(
      zenTaoNotificationsFromView({'allMessages': []}, accountId: 'a1'),
      isEmpty,
    );
  });
}
