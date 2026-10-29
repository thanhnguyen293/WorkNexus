import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_providers.dart';
import 'chat_layout.dart';
import 'chat_message_card.dart';
import 'chat_panels.dart';
import 'chat_side_panel_frame.dart';
import 'chat_snack.dart';
import 'pinned_card_preview.dart';

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
                  _PinnedCard(
                    key: ValueKey(m.gid),
                    thread: t,
                    message: m,
                    users: widget.users,
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

/// One pinned message: a card with its preview, a jump to it in the chat
/// and, for who may pin, an unpin button.
class _PinnedCard extends ConsumerWidget {
  const _PinnedCard({
    super.key,
    required this.thread,
    required this.message,
    required this.users,
  });

  final ChatThreadKey thread;
  final ChatMessage message;
  final Map<int, ChatUser> users;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final serverId = message.serverId;
    return ChatMessageCard(
      message: message,
      users: users,
      label: l.chatPinnedLabel,
      labelIcon: LucideIcons.messageSquareText300,
      body: PinnedCardPreview(message: message),
      onViewOriginal: serverId == null
          ? null
          : () {
              // Slid over the messages, the panel would hide the one
              // jumped to: make way for it.
              if (!ChatLayoutScope.of(context).infoRoom) {
                closeChatSidePanel(ref, thread);
              }
              jumpToChatMessage(ref, thread, serverId);
            },
      trailing: ref.watch(chatCanPinProvider(thread))
          ? AppIconButton(
              icon: LucideIcons.pinOff300,
              tooltip: l.chatUnpin,
              size: AppIconButtonSize.small,
              onPressed: () async {
                final result = await ref
                    .read(chatControllerProvider)
                    .setPinned(message, pinned: false);
                if (result case Err(:final failure)) {
                  if (context.mounted) showChatFailure(context, failure);
                }
              },
            )
          : null,
    );
  }
}
