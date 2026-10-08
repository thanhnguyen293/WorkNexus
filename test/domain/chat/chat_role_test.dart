import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/value_objects/chat_role.dart';

void main() {
  test('codes map to roles; empty and admin-defined ones do not', () {
    expect(ChatRole.fromCode('td'), ChatRole.td);
    expect(ChatRole.fromCode(' dev '), ChatRole.dev);
    expect(ChatRole.fromCode(''), isNull);
    expect(ChatRole.fromCode(null), isNull);
    expect(ChatRole.fromCode('designer'), isNull);
  });

  test('leading roles rank by seniority; engineers and others have none', () {
    expect(
      {for (final r in ChatRole.values) r: r.rank},
      {
        ChatRole.dev: null,
        ChatRole.qa: null,
        ChatRole.others: null,
        ChatRole.pm: ChatRoleRank.lead,
        ChatRole.po: ChatRoleRank.lead,
        ChatRole.td: ChatRoleRank.manager,
        ChatRole.pd: ChatRoleRank.manager,
        ChatRole.qd: ChatRoleRank.manager,
        ChatRole.top: ChatRoleRank.executive,
      },
    );
  });
}
