import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_providers.dart';
import 'chat_labels.dart';
import 'chat_layout.dart';
import 'chat_panels.dart';

/// Under the chat header: the most recently pinned message and how many are
/// pinned. Tap lists them all beside the chat.
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
    final count = widget.pinnedIds.length;

    return Material(
      color: c.surface,
      child: InkWell(
        onTap: () => toggleChatSidePanel(
          ref,
          t,
          ChatSidePanel.pinned,
          infoRoom: ChatLayoutScope.of(context).infoRoom,
        ),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: s.xl4, vertical: s.md),
          decoration: BoxDecoration(
            border: Border(bottom: context.hairlineSide),
          ),
          child: Row(
            children: [
              Container(width: 3, height: s.xl6 - s.md, color: c.accent),
              SizedBox(width: s.lg),
              Icon(PhosphorIconsFill.pushPin, size: s.xl3, color: c.accent),
              SizedBox(width: s.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count > 1
                          ? '${l.chatPinnedMessages} ($count)'
                          : l.chatPinnedMessages,
                      style: context.typography.captionStrong.copyWith(
                        color: c.accent,
                      ),
                    ),
                    Text(
                      preview ?? '…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.bodySm.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(PhosphorIconsLight.caretRight, color: c.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
