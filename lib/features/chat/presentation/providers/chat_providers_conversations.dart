part of 'chat_providers.dart';

final chatConversationsProvider = StreamProvider.autoDispose
    .family<List<ChatConversation>, String>(
      (ref, accountId) =>
          ref.watch(chatRepositoryProvider).watchConversations(accountId),
    );

final chatUsersProvider = StreamProvider.autoDispose
    .family<Map<int, ChatUser>, String>(
      (ref, accountId) => ref
          .watch(chatRepositoryProvider)
          .watchUsers(accountId)
          .map((users) => {for (final u in users) u.userId: u}),
    );

/// Unread messages across all ZenTao accounts (sidebar badge).
final chatUnreadTotalProvider = Provider<int>((ref) {
  var total = 0;
  for (final account in ref.watch(chatAccountsProvider)) {
    final chats =
        ref.watch(chatConversationsProvider(account.id)).asData?.value ??
        const [];
    for (final c in chats) {
      if (!c.hidden && !c.archived) total += c.unreadCount;
    }
  }
  return total;
});

/// The open chat of each account.
final selectedChatGidProvider = StateProvider.family<String?, String>(
  (ref, accountId) => null,
);

/// The tab selected above the chat list.
final chatListTabProvider = StateProvider<ChatListTab>(
  (ref) => ChatListTab.all,
);

/// The chat list filter text.
final chatSearchProvider = StateProvider<String>((ref) => '');

/// The signed-in chat user's id per account.
final chatSelfUserIdProvider = StreamProvider.autoDispose.family<int?, String>(
  (ref, accountId) =>
      ref.watch(chatRepositoryProvider).watchSelfUserId(accountId),
);
