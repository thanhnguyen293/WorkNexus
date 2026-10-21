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

/// Opens a row of [kQuickReactions] centred over [anchor] (global: the top
/// centre of the button that opened it), the ones in [selected] marked, and
/// resolves to the emoji picked, or null when dismissed.
Future<String?> showReactionPicker(
  BuildContext context, {
  required Offset anchor,
  Set<String> selected = const {},
}) => showGeneralDialog<String>(
  context: context,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: Colors.transparent,
  transitionDuration: const Duration(milliseconds: 120),
  pageBuilder: (context, _, _) => CustomSingleChildLayout(
    delegate: _OverAnchor(anchor, margin: context.spacing.md),
    child: _QuickReactionRow(selected: selected),
  ),
  transitionBuilder: (context, animation, _, child) => FadeTransition(
    opacity: animation,
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.9, end: 1).animate(animation),
      alignment: Alignment.bottomCenter,
      child: child,
    ),
  ),
);

class _QuickReactionRow extends StatelessWidget {
  const _QuickReactionRow({required this.selected});

  final Set<String> selected;

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
              selected: selected.contains(emoji),
              onTap: () => Navigator.of(context).pop(emoji),
            ),
        ],
      ),
    );
  }
}

class _EmojiButton extends StatelessWidget {
  const _EmojiButton({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final radius = BorderRadius.circular(context.radii.md);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: s.xxs),
      child: Ink(
        decoration: BoxDecoration(
          color: selected ? c.selectionFill : null,
          borderRadius: radius,
          border: selected ? Border.all(color: c.selectionBorder) : null,
        ),
        child: InkWell(
          mouseCursor: WidgetStateMouseCursor.clickable,
          hoverColor: c.hoverFill,
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(s.md),
            child: Text(emoji, style: context.typography.titleLg),
          ),
        ),
      ),
    );
  }
}

/// Centres the row over the anchor with a small gap (below it when there is
/// no room above), kept on screen.
class _OverAnchor extends SingleChildLayoutDelegate {
  _OverAnchor(this.anchor, {required this.margin});

  final Offset anchor;
  final double margin;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest).deflate(EdgeInsets.all(margin));

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final gap = margin / 2;
    final above = anchor.dy - childSize.height - gap;
    final y = above < margin ? anchor.dy + 3 * margin + gap : above;
    return Offset(
      (anchor.dx - childSize.width / 2).clamp(
        margin,
        size.width - childSize.width - margin,
      ),
      y.clamp(margin, size.height - childSize.height - margin),
    );
  }

  @override
  bool shouldRelayout(_OverAnchor old) =>
      old.anchor != anchor || old.margin != margin;
}

/// Asks which emoji to react to [message] with, over [anchor], and sends it;
/// one the user already reacted with is taken back.
Future<void> reactToMessage(
  BuildContext context,
  WidgetRef ref,
  ChatMessage message, {
  required Offset anchor,
}) async {
  final serverId = message.serverId;
  final chat = (accountId: message.accountId, chatGid: message.chatGid);
  List<MessageReaction> reactionsNow() => serverId == null
      ? const []
      : ref.read(chatReactionsProvider(chat)).value?[serverId] ?? const [];
  final emoji = await showReactionPicker(
    context,
    anchor: anchor,
    selected: {
      for (final r in reactionsNow())
        if (r.mine != null) r.emoji,
    },
  );
  if (emoji == null) return;
  final result = await ref
      .read(reactionControllerProvider)
      .toggle(message, emoji, reactions: reactionsNow());
  if (result case Err(:final failure)) {
    if (context.mounted) showChatFailure(context, failure);
  }
}
