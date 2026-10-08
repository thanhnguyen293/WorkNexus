import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_conversation.dart';
import 'package:work_nexus/features/chat/domain/value_objects/chat_list_tab.dart';

ChatConversation _chat(ChatType type) =>
    ChatConversation(accountId: 'a', gid: 'g', type: type, name: 'n');

void main() {
  test('each tab keeps only its chat types', () {
    expect(ChatListTab.all.matches(_chat(ChatType.other)), isTrue);
    expect(ChatListTab.direct.matches(_chat(ChatType.one2one)), isTrue);
    expect(ChatListTab.direct.matches(_chat(ChatType.group)), isFalse);
    expect(ChatListTab.groups.matches(_chat(ChatType.group)), isTrue);
    expect(ChatListTab.bots.matches(_chat(ChatType.bot)), isTrue);
    expect(ChatListTab.bots.matches(_chat(ChatType.system)), isTrue);
    expect(ChatListTab.bots.matches(_chat(ChatType.one2one)), isFalse);
  });
}
