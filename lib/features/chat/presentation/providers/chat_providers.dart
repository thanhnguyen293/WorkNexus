import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_user.dart';
import '../../domain/entities/link_preview.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/repositories/link_preview_repository.dart';
import '../../domain/usecases/build_reply_thread.dart';
import '../../domain/usecases/load_link_preview.dart';
import '../../domain/value_objects/chat_connection_status.dart';
import '../../domain/value_objects/message_content.dart';
import 'chat_controller.dart';

/// One open thread: which account, which chat.
typedef ChatThreadKey = ({String accountId, String chatGid});

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => getIt<ChatRepository>(),
);

final chatControllerProvider = Provider<ChatController>(
  (ref) => ChatController(ref.watch(chatRepositoryProvider)),
);

/// Chat exists per connected ZenTao account.
final chatAccountsProvider = Provider<List<Account>>((ref) {
  final accounts = ref.watch(accountsProvider).asData?.value ?? const [];
  return [
    for (final a in accounts)
      if (a.providerType == ProviderType.zentao) a,
  ];
});

/// The account the user picked in the chat view (null = not picked yet).
final pickedChatAccountProvider = StateProvider<String?>((ref) => null);

/// The account the chat view shows: the picked one while it still exists,
/// else the first ZenTao account.
final selectedChatAccountIdProvider = Provider<String?>((ref) {
  final accounts = ref.watch(chatAccountsProvider);
  final picked = ref.watch(pickedChatAccountProvider);
  if (accounts.any((a) => a.id == picked)) return picked;
  return accounts.isEmpty ? null : accounts.first.id;
});

/// Logs every ZenTao account into chat. Watched by the always-visible sidebar
/// entry so unread counts are live before the chat view is opened.
final chatAutoConnectProvider = Provider<void>((ref) {
  final controller = ref.watch(chatControllerProvider);
  for (final account in ref.watch(chatAccountsProvider)) {
    controller.connect(account.id);
  }
});

final chatStatusProvider = StreamProvider.autoDispose
    .family<ChatConnectionStatus, String>(
      (ref, accountId) =>
          ref.watch(chatRepositoryProvider).watchStatus(accountId),
    );

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

/// The chat list filter text.
final chatSearchProvider = StateProvider<String>((ref) => '');

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

/// Attachment bytes (images), kept as a [Result] so a failed download renders
/// as a placeholder instead of an exception.
final chatAttachmentProvider = FutureProvider.autoDispose
    .family<
      Result<Uint8List>,
      ({String accountId, MessageContent content, bool thumbnail})
    >(
      (ref, key) => ref
          .watch(chatControllerProvider)
          .loadAttachment(key.accountId, key.content, thumbnail: key.thumbnail),
    );

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

/// Which composer: the chat's own, or the one in its open reply thread.
typedef ChatComposerKey = ({ChatThreadKey chat, bool inThread});

/// The message a composer is replying to (null = not replying), shown above
/// its input until the reply is sent or cancelled.
final chatReplyDraftProvider =
    StateProvider.family<ChatMessage?, ChatComposerKey>((ref, key) => null);

/// Upload progress (0–1) of a pending file message, by message gid.
final chatUploadProgressProvider = StreamProvider.autoDispose
    .family<double, String>(
      (ref, gid) => ref.watch(chatRepositoryProvider).watchUploadProgress(gid),
    );

/// Preview frame of a video message.
final chatVideoThumbnailProvider = FutureProvider.autoDispose
    .family<Result<Uint8List>, ({String accountId, MessageContent video})>(
      (ref, key) => ref
          .watch(chatControllerProvider)
          .videoThumbnail(key.accountId, key.video),
    );

/// Member count of a chat (header subtitle); refetched when the chat opens.
final chatMemberCountProvider = FutureProvider.autoDispose
    .family<Result<int>, ChatThreadKey>(
      (ref, key) => ref
          .watch(chatRepositoryProvider)
          .memberCount(key.accountId, key.chatGid),
    );

/// Preview card data for a web link in a message (null = nothing to show).
final chatLinkPreviewProvider = FutureProvider.autoDispose
    .family<LinkPreview?, String>((ref, url) async {
      final result = await LoadLinkPreview(getIt<LinkPreviewRepository>())(url);
      // Keep previews while the app runs: the repository caches them anyway,
      // and re-creating the provider on every scroll would flicker.
      ref.keepAlive();
      return result.valueOrNull;
    });
