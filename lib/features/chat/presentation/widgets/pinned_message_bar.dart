import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_context_menu.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_providers.dart';
import 'chat_labels.dart';
import 'chat_layout.dart';
import 'chat_panels.dart';
import 'chat_side_panel_frame.dart';
import 'chat_snack.dart';

/// Under the chat header: the most recently pinned message and how many
/// others are pinned. Tap lists them all beside the chat, as cards.
class PinnedMessageBar extends ConsumerStatefulWidget {
  const PinnedMessageBar({
    super.key,
    required this.thread,
    required this.pinnedIds,
    required this.users,
  });

  final ChatThreadKey thread;
  final List<int> pinnedIds;
  final Map<int, ChatUser> users;

  @override
  ConsumerState<PinnedMessageBar> createState() => _PinnedMessageBarState();
}

class _PinnedMessageBarState extends ConsumerState<PinnedMessageBar> {
  int? _requested;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final t = widget.thread;
    final latest = widget.pinnedIds.last;
    final state = ref.watch(
      chatMessageByIdProvider((chat: t, serverId: latest)),
    );
    if (state case AsyncData(value: null) when _requested != latest) {
      _requested = latest;
      ref.read(chatControllerProvider).fetchMessages(t.accountId, t.chatGid, [
        latest,
      ]);
    }
    final message = state.value;
    final preview = message == null
        ? null
        : '${chatUserName(context, widget.users, message.senderId)}: '
              '${message.deleted ? l.chatRetracted : chatPreview(context, message)}';
    final others = widget.pinnedIds.length - 1;
    void openPanel() => toggleChatSidePanel(
      ref,
      t,
      ChatSidePanel.pinned,
      infoRoom: ChatLayoutScope.of(context).infoRoom,
    );

    return Material(
      color: c.surface,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: openPanel,
        child: Container(
          height: kChatSubHeaderHeight,
          padding: EdgeInsets.only(left: s.xl4, right: s.lg),
          decoration: BoxDecoration(
            border: Border(bottom: context.hairlineSide),
          ),
          child: Row(
            children: [
              Icon(
                LucideIcons.messageSquareText300,
                size: s.xl4,
                color: c.accent,
              ),
              SizedBox(width: s.lg),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.chatPinnedBarTitle,
                      style: context.typography.bodyStrong.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      preview ?? '…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.bodySm.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (others > 0) ...[
                SizedBox(width: s.md),
                AppButton.outlinedNeutral(
                  size: AppButtonSize.small,
                  onPressed: openPanel,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l.chatMorePins(others)),
                      SizedBox(width: s.xs),
                      Icon(LucideIcons.chevronDown300, size: s.xl2),
                    ],
                  ),
                ),
              ],
              SizedBox(width: s.xs),
              _PinnedBarMenu(thread: t, message: message),
            ],
          ),
        ),
      ),
    );
  }
}

/// The bar's "…": jump to the pinned message, or unpin it.
class _PinnedBarMenu extends ConsumerWidget {
  const _PinnedBarMenu({required this.thread, required this.message});

  final ChatThreadKey thread;
  final ChatMessage? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final m = message;
    final serverId = m?.serverId;
    final canPin = ref.watch(chatCanPinProvider(thread));
    return Builder(
      builder: (button) => AppIconButton(
        icon: LucideIcons.ellipsis300,
        tooltip: l.chatMoreActions,
        onPressed: m == null || serverId == null
            ? null
            : () async {
                final box = button.findRenderObject() as RenderBox?;
                if (box == null) return;
                final picked = await showAppContextMenu(
                  button,
                  at: box.localToGlobal(box.size.bottomLeft(Offset.zero)),
                  entries: [
                    AppMenuEntry(
                      icon: LucideIcons.messageSquareShare300,
                      label: l.chatViewOriginal,
                    ),
                    if (canPin)
                      AppMenuEntry(
                        icon: LucideIcons.pinOff300,
                        label: l.chatUnpin,
                        destructive: true,
                      ),
                  ],
                );
                if (picked == 0) {
                  jumpToChatMessage(ref, thread, serverId);
                } else if (picked == 1) {
                  final result = await ref
                      .read(chatControllerProvider)
                      .setPinned(m, pinned: false);
                  if (result case Err(:final failure)) {
                    if (button.mounted) showChatFailure(button, failure);
                  }
                }
              },
      ),
    );
  }
}
