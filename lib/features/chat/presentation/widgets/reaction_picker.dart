import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_popup_card.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/message_reaction.dart';
import '../providers/chat_providers.dart';
import '../providers/reaction_controller.dart';
import 'chat_snack.dart';

/// The emoji offered for a quick reaction.
const kQuickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

/// Opens a row of [kQuickReactions] above [anchor] (global: the message's top
/// edge) and resolves to the emoji picked, or null when dismissed.
Future<String?> showReactionPicker(
  BuildContext context, {
  required Offset anchor,
}) => showGeneralDialog<String>(
  context: context,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: Colors.transparent,
  transitionDuration: const Duration(milliseconds: 120),
  pageBuilder: (context, _, _) => CustomSingleChildLayout(
    delegate: _AboveAnchor(anchor, margin: context.spacing.md),
    child: const _QuickReactionRow(),
  ),
  transitionBuilder: (context, animation, _, child) =>
      FadeTransition(opacity: animation, child: child),
);

class _QuickReactionRow extends StatelessWidget {
  const _QuickReactionRow();

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return AppPopupCard(
      padding: EdgeInsets.all(s.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final emoji in kQuickReactions)
            _EmojiButton(
              emoji: emoji,
              onTap: () => Navigator.of(context).pop(emoji),
            ),
        ],
      ),
    );
  }
}

class _EmojiButton extends StatelessWidget {
  const _EmojiButton({required this.emoji, required this.onTap});

  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      hoverColor: context.colors.hoverFill,
      borderRadius: BorderRadius.circular(context.radii.md),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(s.md),
        child: Text(emoji, style: context.typography.titleLg),
      ),
    );
  }
}

/// Puts the row just above the anchor (below it when there is no room), kept
/// on screen.
class _AboveAnchor extends SingleChildLayoutDelegate {
  _AboveAnchor(this.anchor, {required this.margin});

  final Offset anchor;
  final double margin;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest).deflate(EdgeInsets.all(margin));

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final above = anchor.dy - childSize.height - margin;
    final y = above < margin ? anchor.dy + margin : above;
    return Offset(
      anchor.dx.clamp(margin, size.width - childSize.width - margin),
      y.clamp(margin, size.height - childSize.height - margin),
    );
  }

  @override
  bool shouldRelayout(_AboveAnchor old) =>
      old.anchor != anchor || old.margin != margin;
}

/// Asks which emoji to react to [message] with (above it, as [context]'s
/// widget is) and sends it; one the user already reacted with is taken back.
Future<void> reactToMessage(
  BuildContext context,
  WidgetRef ref,
  ChatMessage message,
) async {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null) return;
  final emoji = await showReactionPicker(
    context,
    anchor: box.localToGlobal(Offset.zero),
  );
  if (emoji == null) return;
  final serverId = message.serverId;
  final chat = (accountId: message.accountId, chatGid: message.chatGid);
  final reactions = serverId == null
      ? const <MessageReaction>[]
      : ref.read(chatReactionsProvider(chat)).value?[serverId] ?? const [];
  final result = await ref
      .read(reactionControllerProvider)
      .toggle(message, emoji, reactions: reactions);
  if (result case Err(:final failure)) {
    if (context.mounted) showChatFailure(context, failure);
  }
}
