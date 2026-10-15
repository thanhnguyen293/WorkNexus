import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/features/notifications/domain/entities/zentao_notification.dart';
import 'package:work_nexus/features/notifications/domain/usecases/filter_self_notifications.dart';

ZenTaoNotification _n(String id, String summary, {String accountId = 'a1'}) =>
    ZenTaoNotification(
      accountId: accountId,
      id: id,
      summary: summary,
      objectType: 'task',
      objectId: '12974',
    );

Account _account(String id, String handle) => Account(
  id: id,
  workspaceId: 'ws1',
  providerType: ProviderType.zentao,
  handle: handle,
);

void main() {
  group('FilterSelfNotifications', () {
    const filter = FilterSelfNotifications();
    final accounts = [
      _account('a1', 'Sunshine_VN_Golang'),
      _account('a2', 'Dan'),
    ];
    final realnames = {'a1': 'Son Vu', 'a2': 'Dan Nguyen'};

    test('filters out self action matching account handle', () {
      final items = [
        _n('1', 'Sunshine_VN_Golang started Task'),
        _n('2', 'JunNg assigned Bug'),
      ];

      final filtered = filter(
        items,
        accounts: accounts,
        realnamesByAccountId: realnames,
      );

      expect(filtered.map((n) => n.id), ['2']);
    });

    test('filters out self action matching account realname', () {
      final items = [
        _n('1', 'Son Vu started Task'),
        _n('2', 'JunNg assigned Bug'),
      ];

      final filtered = filter(
        items,
        accounts: accounts,
        realnamesByAccountId: realnames,
      );

      expect(filtered.map((n) => n.id), ['2']);
    });

    test('is case-insensitive when matching actor', () {
      final items = [
        _n('1', 'sunshine_vn_golang started Task'),
        _n('2', 'son vu closed Bug'),
        _n('3', 'JunNg assigned Bug'),
      ];

      final filtered = filter(
        items,
        accounts: accounts,
        realnamesByAccountId: realnames,
      );

      expect(filtered.map((n) => n.id), ['3']);
    });

    test('filters Chinese action summaries matching user name', () {
      final items = [
        _n('1', 'Sunshine_VN_Golang开始了Task'),
        _n('2', 'Son Vu指派了Bug'),
        _n('3', 'Thanh指派了Bug'),
      ];

      final filtered = filter(
        items,
        accounts: accounts,
        realnamesByAccountId: realnames,
      );

      expect(filtered.map((n) => n.id), ['3']);
    });

    test(
      'does not filter another user with prefix name (e.g. Daniel vs Dan)',
      () {
        final items = [
          _n('1', 'Daniel assigned Bug', accountId: 'a2'),
          _n('2', 'Dan assigned Bug', accountId: 'a2'),
        ];

        final filtered = filter(
          items,
          accounts: accounts,
          realnamesByAccountId: realnames,
        );

        expect(filtered.map((n) => n.id), ['1']);
      },
    );

    test('fallback: filters unknown verb starting with user handle', () {
      final items = [
        _n('1', 'Sunshine_VN_Golang pinged the channel'),
        _n('2', 'JunNg pinged the channel'),
      ];

      final filtered = filter(
        items,
        accounts: accounts,
        realnamesByAccountId: realnames,
      );

      expect(filtered.map((n) => n.id), ['2']);
    });

    test('returns original list when notifications or accounts are empty', () {
      expect(filter(const [], accounts: accounts), isEmpty);

      final items = [_n('1', 'Sunshine_VN_Golang started Task')];
      expect(filter(items, accounts: const []), items);
    });
  });
}
