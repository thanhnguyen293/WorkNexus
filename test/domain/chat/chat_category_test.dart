import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_conversation.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_repository.dart';
import 'package:work_nexus/features/chat/domain/usecases/list_chat_categories.dart';
import 'package:work_nexus/features/chat/domain/usecases/rename_chat_category.dart';
import 'package:work_nexus/features/chat/domain/usecases/set_chat_category.dart';
import 'package:work_nexus/features/chat/domain/value_objects/chat_list_filter.dart';
import 'package:work_nexus/features/chat/domain/value_objects/chat_list_tab.dart';

class _Repo extends Mock implements ChatRepository {}

ChatConversation _chat(
  String gid, {
  String category = '',
  int unread = 0,
  bool hidden = false,
}) => ChatConversation(
  accountId: 'a',
  gid: gid,
  type: ChatType.group,
  name: gid,
  category: category,
  unreadCount: unread,
  hidden: hidden,
);

void main() {
  late _Repo repo;

  setUp(() {
    repo = _Repo();
    when(
      () => repo.setChatCategory(any(), any(), any()),
    ).thenAnswer((_) async => const Ok(null));
  });

  test('categories are listed A–Z with their unread, listed chats only', () {
    final categories = const ListChatCategories()([
      _chat('1', category: 'work', unread: 2),
      _chat('2', category: 'Family', unread: 1),
      _chat('3', category: 'work', unread: 3),
      _chat('4'),
      _chat('5', category: 'Old', hidden: true),
    ]);
    expect(categories, {'Family': 1, 'work': 5});
    expect(categories.keys.toList(), ['Family', 'work']);
  });

  test(
    'filing a chat sends the trimmed name, nothing when unchanged',
    () async {
      final set = SetChatCategory(repo);
      await set(_chat('1', category: 'Work'), ' Work ');
      verifyNever(() => repo.setChatCategory(any(), any(), any()));
      await set(_chat('1', category: 'Work'), ' Projects ');
      verify(() => repo.setChatCategory('a', ['1'], 'Projects')).called(1);
      await set(_chat('1', category: 'Work'), '');
      verify(() => repo.setChatCategory('a', ['1'], '')).called(1);
    },
  );

  test('renaming or deleting refiles every chat of the category', () async {
    final rename = RenameChatCategory(repo);
    final chats = [
      _chat('1', category: 'Work'),
      _chat('2'),
      _chat('3', category: 'Work'),
    ];
    await rename('a', chats, from: 'Work', to: 'Projects');
    verify(() => repo.setChatCategory('a', ['1', '3'], 'Projects')).called(1);
    await rename('a', chats, from: 'Work', to: '');
    verify(() => repo.setChatCategory('a', ['1', '3'], '')).called(1);
    expect(await rename('a', chats, from: 'None', to: 'X'), isA<Err<void>>());
  });

  test('the list filter combines tab, unread and picked tags', () {
    final work = _chat('1', category: 'Work', unread: 2);
    final quiet = _chat('2', category: 'Work');
    final home = _chat('3', category: 'Home', unread: 1);
    final hidden = _chat('4', unread: 5, hidden: true);
    List<String> shown(ChatListFilter f) => [
      for (final c in [work, quiet, home, hidden])
        if (f.matches(c)) c.gid,
    ];
    expect(shown(const ChatListFilter()), ['1', '2', '3']);
    expect(shown(const ChatListFilter(unreadOnly: true)), ['1', '3']);
    expect(shown(const ChatListFilter(categories: {'Work'})), ['1', '2']);
    expect(
      shown(const ChatListFilter(unreadOnly: true, categories: {'Work'})),
      ['1'],
    );
    expect(shown(const ChatListFilter(tab: ChatListTab.direct)), isEmpty);
    expect(const ChatListFilter().isNarrowed, isFalse);
  });
}
