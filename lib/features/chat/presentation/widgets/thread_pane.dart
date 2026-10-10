import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/widgets/file_drop_target.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_providers.dart';
import 'chat_composer.dart';
import 'chat_file_send.dart';
import 'chat_files_panel.dart';
import 'chat_floating_video.dart';
import 'chat_info_panel.dart';
import 'chat_labels.dart';
import 'chat_layout.dart';
import 'chat_members_panel.dart';
import 'chat_panels.dart';
import 'chat_read_only_bar.dart';
import 'chat_side_panel_host.dart';
import 'chat_snack.dart';
import 'chat_text_scale.dart';
import 'chat_thread_header.dart';
import 'chat_wallpaper.dart';
import 'message_list.dart';
import 'pinned_message_bar.dart';
import 'pinned_messages_panel.dart';
import 'reply_thread_panel.dart';

/// Right pane: one open chat. Pulls the newest page and marks the chat read
/// when it opens (keyed per chat by the parent, so this runs on every switch).
class ThreadPane extends ConsumerStatefulWidget {
  const ThreadPane({super.key, required this.thread, this.backgroundKey});

  final ChatThreadKey thread;

  /// Shared by every chat's pane so the background survives a switch.
  final GlobalKey? backgroundKey;

  @override
  ConsumerState<ThreadPane> createState() => _ThreadPaneState();
}

class _ThreadPaneState extends ConsumerState<ThreadPane> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    final controller = ref.read(chatControllerProvider);
    final t = widget.thread;
    // Membership may have changed since the count was kept.
    ref.invalidate(chatMemberCountProvider(t));
    final refreshed = await controller.refresh(t.accountId, t.chatGid);
    if (refreshed case Err(:final failure)) {
      if (mounted) showChatFailure(context, failure);
      return;
    }
    await controller.markRead(t.accountId, t.chatGid);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.thread;
    final chats =
        ref.watch(chatConversationsProvider(t.accountId)).asData?.value ??
        const <ChatConversation>[];
    final chat = chats.where((c) => c.gid == t.chatGid).firstOrNull;
    final users =
        ref.watch(chatUsersProvider(t.accountId)).asData?.value ??
        const <int, ChatUser>{};
    final openThread = ref.watch(openReplyThreadProvider(t));
    final sidePanel = effectiveSidePanel(
      ref,
      t,
      infoRoom: ChatLayoutScope.of(context).infoRoom,
    );
    final pinned = chat?.pinnedMessageIds ?? const <int>[];
    // Files dropped anywhere on the conversation go through the same send
    // preview as picked ones.
    final canSend = ref.watch(chatCanSendProvider(t));
    final messages = FileDropTarget(
      enabled: canSend,
      hint: AppL10n.of(context).dropFilesToSend,
      onDrop: (files) => previewAndSendChatFiles(
        context,
        ref,
        draftKey: (chat: t, inThread: false),
        files: files,
      ),
      child: Column(
        children: [
          ChatThreadHeader(thread: t, chat: chat, users: users),
          if (pinned.isNotEmpty)
            PinnedMessageBar(thread: t, pinnedIds: pinned, users: users),
          Expanded(
            // Behind the list rather than inside it, so it also shows while
            // the messages load.
            child: Stack(
              children: [
                ChatBackground(
                  key: widget.backgroundKey,
                  child: ChatTextScale(
                    child: MessageList(
                      // The background is reused across chats; the list is
                      // not.
                      key: ValueKey(t),
                      thread: t,
                      showSenders: chat?.type != ChatType.one2one,
                    ),
                  ),
                ),
                // A video scrolled out of view plays on over the list.
                Positioned.fill(child: ChatFloatingVideo(thread: t)),
              ],
            ),
          ),
          if (canSend)
            ChatTextScale(
              child: ChatComposer(
                thread: t,
                hint: chat == null
                    ? null
                    : AppL10n.of(
                        context,
                      ).chatMessageTo(chatTitle(context, chat, users)),
              ),
            )
          else
            ChatReadOnlyBar(adminsOnly: chat?.committers.trim() == r'$ADMINS'),
        ],
      ),
    );
    final Widget? panel = openThread != null
        ? ChatTextScale(
            child: ReplyThreadPanel(
              key: ValueKey('thread-$openThread'),
              chat: t,
              rootId: openThread,
            ),
          )
        : chat == null
        ? null
        : switch (sidePanel) {
            ChatSidePanel.info => ChatInfoPanel(
              thread: t,
              chat: chat,
              users: users,
            ),
            ChatSidePanel.pinned => ChatTextScale(
              child: PinnedMessagesPanel(thread: t, chat: chat, users: users),
            ),
            ChatSidePanel.files => ChatFilesPanel(thread: t),
            ChatSidePanel.members => ChatMembersPanel(
              thread: t,
              chat: chat,
              users: users,
            ),
            null => null,
          };
    return ChatSidePanelHost(
      messages: messages,
      panel: panel,
      onDismiss: () => openThread != null
          ? ref.read(openReplyThreadProvider(t).notifier).state = null
          : closeChatSidePanel(ref, t),
    );
  }
}
