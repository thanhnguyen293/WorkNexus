part of 'chat_providers.dart';

/// How many of the newest messages a thread shows; grows as older pages load.
final chatMessageLimitProvider = StateProvider.family<int, ChatThreadKey>(
  (ref, key) => ChatController.pageSize,
);

final chatMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, ChatThreadKey>((ref, key) {
      final limit = ref.watch(chatMessageLimitProvider(key));
      return ref
          .watch(chatRepositoryProvider)
          .watchMessages(key.accountId, key.chatGid, limit: limit);
    });

/// Every reply in a chat (threads and "N replies" counts are built from it).
final chatRepliesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, ChatThreadKey>(
      (ref, key) => ref
          .watch(chatRepositoryProvider)
          .watchReplies(key.accountId, key.chatGid),
    );

/// Thread summary (count, repliers, last reply) per thread root of a chat.
final chatThreadSummariesProvider = Provider.autoDispose
    .family<Map<int, ThreadSummary>, ChatThreadKey>((ref, key) {
      final replies = ref.watch(chatRepliesProvider(key)).asData?.value;
      if (replies == null) return const {};
      return ref.watch(chatControllerProvider).threadSummaries(replies);
    });

/// Reply count per thread root of a chat.
final chatReplyCountsProvider = Provider.autoDispose
    .family<Map<int, int>, ChatThreadKey>((ref, key) {
      final replies = ref.watch(chatRepliesProvider(key)).asData?.value;
      if (replies == null) return const {};
      return ref.watch(chatControllerProvider).replyCounts(replies);
    });

/// One message by server id (e.g. the original of a reply).
final chatMessageByIdProvider = StreamProvider.autoDispose
    .family<ChatMessage?, ({ChatThreadKey chat, int serverId})>(
      (ref, key) => ref
          .watch(chatRepositoryProvider)
          .watchMessage(key.chat.accountId, key.chat.chatGid, key.serverId),
    );

/// The reply thread open beside a chat: its root message's server id.
final openReplyThreadProvider = StateProvider.family<int?, ChatThreadKey>(
  (ref, key) => null,
);

/// A message (server id) the chat's list should scroll to — set by tapping a
/// reply's quote.
final chatJumpRequestProvider = StateProvider.family<int?, ChatThreadKey>(
  (ref, key) => null,
);

/// The message (server id) briefly highlighted after a jump to it.
final chatHighlightedMessageProvider =
    StateProvider.family<int?, ChatThreadKey>((ref, key) => null);

/// Whether the signed-in user may post in a chat (true until the chat and
/// the user are known, so the composer does not blink away and back).
final chatCanSendProvider = Provider.autoDispose.family<bool, ChatThreadKey>((
  ref,
  key,
) {
  final chat = ref
      .watch(chatConversationsProvider(key.accountId))
      .value
      ?.where((c) => c.gid == key.chatGid)
      .firstOrNull;
  if (chat == null) return true;
  final self = ref.watch(chatSelfUserIdProvider(key.accountId)).value;
  final users = ref.watch(chatUsersProvider(key.accountId)).value;
  return ref
      .watch(chatControllerProvider)
      .canSend(chat, selfUserId: self, selfAccount: users?[self]?.account);
});

/// Whether the signed-in user may pin messages in a chat.
final chatCanPinProvider = Provider.autoDispose.family<bool, ChatThreadKey>((
  ref,
  key,
) {
  final chat = ref
      .watch(chatConversationsProvider(key.accountId))
      .value
      ?.where((c) => c.gid == key.chatGid)
      .firstOrNull;
  if (chat == null) return false;
  final self = ref.watch(chatSelfUserIdProvider(key.accountId)).value;
  final users = ref.watch(chatUsersProvider(key.accountId)).value;
  return ref
      .watch(chatControllerProvider)
      .canPin(chat, selfUserId: self, selfAccount: users?[self]?.account);
});

/// Whether message [serverId] is pinned in its chat.
final chatIsPinnedProvider = Provider.autoDispose
    .family<bool, ({ChatThreadKey chat, int serverId})>(
      (ref, key) =>
          ref
              .watch(chatConversationsProvider(key.chat.accountId))
              .value
              ?.where((c) => c.gid == key.chat.chatGid)
              .firstOrNull
              ?.pinnedMessageIds
              .contains(key.serverId) ??
          false,
    );

/// Which composer: the chat's own, or the one in its open reply thread.
typedef ChatComposerKey = ({ChatThreadKey chat, bool inThread});

/// The message a composer is replying to (null = not replying), shown above
/// its input until the reply is sent or cancelled.
final chatReplyDraftProvider =
    StateProvider.family<ChatMessage?, ChatComposerKey>((ref, key) => null);
