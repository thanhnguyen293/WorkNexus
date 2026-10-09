import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/debug/app_talker.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/platform/desktop_window_service.dart';
import '../../../../core/settings/app_settings.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_providers.dart';
import 'chat_labels.dart';
import 'chat_panels.dart';

/// Raises a desktop notification for each new message the user is not
/// already looking at; clicking one brings the window up on that chat.
/// Wraps the app shell so it works whichever view is open.
class ChatNotificationListener extends ConsumerStatefulWidget {
  const ChatNotificationListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ChatNotificationListener> createState() =>
      _ChatNotificationListenerState();
}

class _ChatNotificationListenerState
    extends ConsumerState<ChatNotificationListener> {
  StreamSubscription<ChatMessage>? _incoming;
  StreamSubscription<String>? _taps;

  @override
  void initState() {
    super.initState();
    _incoming = ref
        .read(chatControllerProvider)
        .watchIncoming()
        .listen(_onMessage);
    final notifier = ref.read(desktopNotifierProvider);
    _taps = notifier.taps.listen(_onTap);
    // Ask for permission at launch, not when the first message arrives (its
    // notification would be lost behind the macOS prompt).
    unawaited(notifier.initialize());
  }

  @override
  void dispose() {
    _incoming?.cancel();
    _taps?.cancel();
    super.dispose();
  }

  Future<void> _onMessage(ChatMessage message) async {
    final focused = await const DesktopWindowService().isFocused();
    if (!mounted) return;
    final accountId = message.accountId;
    final chats =
        ref.read(chatConversationsProvider(accountId)).asData?.value ??
        const <ChatConversation>[];
    final chat = chats.where((c) => c.gid == message.chatGid).firstOrNull;
    final shownAccount = ref.read(selectedChatAccountIdProvider);
    final shownGid = ref.read(chatOpenProvider) && shownAccount != null
        ? ref.read(selectedChatGidProvider(shownAccount))
        : null;
    final settings = ref.read(appSettingsProvider);
    final notify = ref
        .read(chatControllerProvider)
        .shouldNotify(
          message,
          enabled: settings.chatNotifications,
          whileViewing: settings.chatNotifyWhileViewing,
          appFocused: focused,
          visibleChat: shownAccount != null && shownGid != null
              ? (accountId: shownAccount, chatGid: shownGid)
              : null,
          conversation: chat,
        );
    appTalker.debug(
      'Notifications: message ${message.gid} in ${message.chatGid} '
      '(focused: $focused, open: $shownGid) -> ${notify ? 'notify' : 'skip'}',
    );
    if (!notify) return;

    final users =
        ref.read(chatUsersProvider(accountId)).asData?.value ??
        const <int, ChatUser>{};
    final sender = chatUserName(context, users, message.senderId);
    final preview = chatPreview(context, message);
    final direct = chat == null || chat.type == ChatType.one2one;
    await ref
        .read(desktopNotifierProvider)
        .show(
          // One notification per chat: a newer message replaces the last.
          id: Object.hash(accountId, message.chatGid) & 0x7fffffff,
          title: chat == null ? sender : chatTitle(context, chat, users),
          body: direct ? preview : '$sender: $preview',
          imageUrl:
              (chat == null ? null : chatAvatarStyle(chat, users).imageUrl) ??
              chatAvatarUrl(users, message.senderId),
          payload: jsonEncode({
            'a': accountId,
            'c': message.chatGid,
            'm': ?message.serverId,
          }),
        );
  }

  Future<void> _onTap(String payload) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException {
      return;
    }
    if (decoded case {'a': final String accountId, 'c': final String gid}) {
      await const DesktopWindowService().bringToFront();
      if (!mounted) return;
      showChatView(ref);
      ref.read(pickedChatAccountProvider.notifier).state = accountId;
      ref.read(selectedChatGidProvider(accountId).notifier).state = gid;
      // The tapped message, found (loading older pages if need be) and
      // highlighted once the chat shows.
      final serverId = decoded['m'];
      appTalker.info('Notifications: tapped $gid, message $serverId');
      if (serverId is int) {
        jumpToChatMessage(ref, (accountId: accountId, chatGid: gid), serverId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep each account's chats and users loaded so a notification can name
    // the chat and sender even while the chat view is closed.
    for (final account in ref.watch(chatAccountsProvider)) {
      ref
        ..watch(chatConversationsProvider(account.id))
        ..watch(chatUsersProvider(account.id));
    }
    return widget.child;
  }
}
