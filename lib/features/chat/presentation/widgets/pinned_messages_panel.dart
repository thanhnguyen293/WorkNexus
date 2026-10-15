import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_providers.dart';
import 'chat_layout.dart';
import 'chat_panels.dart';
import 'chat_side_panel_frame.dart';
import 'message_bubble.dart';

/// Beside the chat: every pinned message, most recently pinned first.
/// Pinned messages older than what is loaded are fetched from the server.
class PinnedMessagesPanel extends ConsumerStatefulWidget {
  const PinnedMessagesPanel({
    super.key,
    required this.thread,
    required this.chat,
    required this.users,
  });

  final ChatThreadKey thread;
  final ChatConversation chat;
  final Map<int, ChatUser> users;

  @override
  ConsumerState<PinnedMessagesPanel> createState() =>
      _PinnedMessagesPanelState();
}

class _PinnedMessagesPanelState extends ConsumerState<PinnedMessagesPanel> {
  /// Ids asked for (in flight or answered), and those whose fetch answered.
  final _requested = <int>{};
  final _answered = <int>{};

  /// The last fetch failed: its ids stop spinning and offer a retry.
  bool _failed = false;

  Future<void> _fetchMissing(List<int> ids) async {
    final missing = ids.where(_requested.add).toList();
    if (missing.isEmpty) return;
    final t = widget.thread;
    final result = await ref
        .read(chatControllerProvider)
        .fetchMessages(t.accountId, t.chatGid, missing);
    if (!mounted) return;
    setState(() {
      _answered.addAll(missing);
      _failed = result is Err;
    });
  }

  void _retry(List<int> missing) => setState(() {
    _failed = false;
    _requested.removeAll(missing);
    _answered.removeAll(missing);
  });

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final t = widget.thread;
    final ids = widget.chat.pinnedMessageIds.reversed.toList();
    final messages = <ChatMessage>[];
    final missing = <int>[];
    for (final id in ids) {
      final found = ref
          .watch(chatMessageByIdProvider((chat: t, serverId: id)))
          .value;
      found == null ? missing.add(id) : messages.add(found);
    }
    if (missing.isNotEmpty && !_failed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchMissing(missing);
      });
    }
    // A message the server answered for but didn't return is gone: it
    // isn't waited for.
    final waiting = missing.any((id) => !_answered.contains(id));
    return ChatSidePanelFrame(
      title: l.chatPinnedMessages,
      onBack: () => backToChatInfo(
        ref,
        t,
        infoRoom: ChatLayoutScope.of(context).infoRoom,
      ),
      onClose: () => closeChatSidePanel(ref, t),
      child: ids.isEmpty
          ? AppStateView.empty(
              compact: true,
              icon: LucideIcons.pin300,
              title: l.chatNoPinned,
            )
          : messages.isEmpty && _failed
          ? AppStateView.error(compact: true, onRetry: () => _retry(missing))
          : ListView(
              padding: EdgeInsets.all(context.spacing.xl3),
              children: [
                for (final m in messages)
                  MessageBubble(
                    key: ValueKey(m.gid),
                    chat: t,
                    message: m,
                    users: widget.users,
                    onOpenThread: (id) => openReplyThread(ref, t, id),
                    onReply: (m) =>
                        ref
                                .read(
                                  chatReplyDraftProvider((
                                    chat: t,
                                    inThread: false,
                                  )).notifier,
                                )
                                .state =
                            m,
                  ),
                if (_failed)
                  Padding(
                    padding: EdgeInsets.only(top: context.spacing.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppInlineNote(
                            text: l.stateLoadFailedTitle,
                            isError: true,
                          ),
                        ),
                        AppButton.textNeutral(
                          size: AppButtonSize.extraSmall,
                          icon: LucideIcons.refreshCw300,
                          onPressed: () => _retry(missing),
                          child: Text(l.retry),
                        ),
                      ],
                    ),
                  )
                else if (waiting)
                  const AppInlineSpinner(),
              ],
            ),
    );
  }
}
