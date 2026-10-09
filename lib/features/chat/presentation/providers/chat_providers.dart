import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/error/result.dart';
import '../../../../core/platform/desktop_notifier.dart';
import '../../../../core/settings/app_settings.dart';
import '../../domain/entities/chat_cache_usage.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_user.dart';
import '../../domain/entities/link_preview.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/repositories/link_preview_repository.dart';
import '../../domain/usecases/build_reply_thread.dart';
import '../../domain/usecases/load_link_preview.dart';
import '../../domain/value_objects/chat_connection_status.dart';
import '../../domain/value_objects/chat_list_tab.dart';
import '../../domain/value_objects/message_content.dart';
import 'chat_controller.dart';

/// One open thread: which account, which chat.
typedef ChatThreadKey = ({String accountId, String chatGid});

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => getIt<ChatRepository>(),
);

/// OS notifications for new messages.
final desktopNotifierProvider = Provider<DesktopNotifier>(
  (ref) => getIt<DesktopNotifier>(),
);

/// Whether the OS lets the app show notifications; null where unknown.
/// Invalidate to check again (e.g. when the app comes back to the front).
final chatNotificationPermissionProvider = FutureProvider.autoDispose<bool?>(
  (ref) => ref.watch(desktopNotifierProvider).permissionGranted(),
);

/// The user closed the "notifications are blocked" bar (until restart).
final chatNotificationWarningDismissedProvider = StateProvider<bool>(
  (ref) => false,
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
  // Also applies the attachment cache and video auto-download limits from
  // settings (here because this runs at launch, before the chat view is
  // opened).
  controller.setCacheLimit(
    ref.watch(appSettingsProvider.select((s) => s.chatCacheLimitMb)) *
        1024 *
        1024,
  );
  final (autoVideos, autoVideoMb) = ref.watch(
    appSettingsProvider.select(
      (s) => (s.chatAutoDownloadVideos, s.chatAutoDownloadVideoMb),
    ),
  );
  controller.setVideoAutoDownloadLimit(
    autoVideos ? autoVideoMb * 1024 * 1024 : 0,
  );
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

/// The tab selected above the chat list.
final chatListTabProvider = StateProvider<ChatListTab>(
  (ref) => ChatListTab.all,
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
    >((ref, key) async {
      final result = await ref
          .watch(chatControllerProvider)
          .loadAttachment(key.accountId, key.content, thumbnail: key.thumbnail);
      // Loading an original downloads it: refresh "is it downloaded?" so
      // size badges go away.
      if (!key.thumbnail && result is Ok && ref.mounted) {
        ref.invalidate(
          chatAttachmentCachedProvider((
            accountId: key.accountId,
            content: key.content,
          )),
        );
      }
      return result;
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

/// Panels that can open beside a chat instead of a reply thread.
enum ChatSidePanel { info, pinned, files }

/// A chat's image and file messages stored locally, newest first.
final chatAttachmentsProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, ChatThreadKey>(
      (ref, key) => ref
          .watch(chatRepositoryProvider)
          .watchAttachments(key.accountId, key.chatGid),
    );

final chatSidePanelProvider =
    StateProvider.family<ChatSidePanel?, ChatThreadKey>((ref, key) => null);

/// The signed-in chat user's id per account.
final chatSelfUserIdProvider = StreamProvider.autoDispose.family<int?, String>(
  (ref, accountId) =>
      ref.watch(chatRepositoryProvider).watchSelfUserId(accountId),
);

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

/// An attachment of a chat account (the key of the download providers).
typedef ChatAttachmentKey = ({String accountId, MessageContent content});

/// Whether an attachment's original is already downloaded.
final chatAttachmentCachedProvider = FutureProvider.autoDispose
    .family<bool, ChatAttachmentKey>(
      (ref, key) => ref
          .watch(chatRepositoryProvider)
          .isAttachmentCached(key.accountId, key.content),
    );

/// Download progress (0–1) of an attachment's original.
final chatDownloadProgressProvider = StreamProvider.autoDispose
    .family<double, ChatAttachmentKey>(
      (ref, key) => ref
          .watch(chatRepositoryProvider)
          .watchDownloadProgress(key.accountId, key.content),
    );

/// Attachments being downloaded because the user tapped them.
final chatDownloadingProvider = StateProvider<Set<ChatAttachmentKey>>(
  (ref) => const {},
);

/// Disk space used by chat attachments (re-read when the dialog opens).
final chatCacheUsageProvider =
    FutureProvider.autoDispose<Result<ChatCacheUsage>>(
      (ref) => ref.watch(chatRepositoryProvider).cacheUsage(),
    );

/// User ids of a group's members.
final chatMembersProvider = FutureProvider.autoDispose
    .family<Result<List<int>>, ChatThreadKey>(
      (ref, key) =>
          ref.watch(chatRepositoryProvider).members(key.accountId, key.chatGid),
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
    .family<Result<Uint8List>, ({String accountId, MessageContent video})>((
      ref,
      key,
    ) {
      // Re-made once a video too big to preview is downloaded on request.
      ref.watch(
        chatAttachmentCachedProvider((
          accountId: key.accountId,
          content: key.video,
        )),
      );
      return ref
          .watch(chatControllerProvider)
          .videoThumbnail(key.accountId, key.video);
    });

/// Length of a downloaded video. Waits for the preview frame, whose making
/// downloads small videos, and re-reads once a big one is downloaded on
/// request.
final chatVideoDurationProvider = FutureProvider.autoDispose
    .family<Result<Duration>, ({String accountId, MessageContent video})>((
      ref,
      key,
    ) async {
      await ref.watch(chatVideoThumbnailProvider(key).future);
      return ref
          .watch(chatRepositoryProvider)
          .videoDuration(key.accountId, key.video);
    });

/// Member count of a chat (header subtitle); refetched when the chat opens.
///
/// Kept once known: switching chats otherwise refetched it each time and
/// the header's "N members" blinked out while it loaded. Opening a chat
/// refreshes it in place (the old count shows meanwhile).
final chatMemberCountProvider = FutureProvider.autoDispose
    .family<Result<int>, ChatThreadKey>((ref, key) async {
      final result = await ref
          .watch(chatRepositoryProvider)
          .memberCount(key.accountId, key.chatGid);
      if (result is Ok) ref.keepAlive();
      return result;
    });

/// Preview card data for a web link in a message (null = nothing to show).
final chatLinkPreviewProvider = FutureProvider.autoDispose
    .family<LinkPreview?, String>((ref, url) async {
      final result = await LoadLinkPreview(getIt<LinkPreviewRepository>())(url);
      // Keep previews while the app runs: the repository caches them anyway,
      // and re-creating the provider on every scroll would flicker.
      ref.keepAlive();
      return result.valueOrNull;
    });
