import 'package:flutter/material.dart';

import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import 'chat_avatar.dart';
import 'chat_style.dart';

/// A miniature chat in [style]: its background, a separator, an incoming
/// bubble with an avatar and an own bubble, in the style's colours, corner
/// radius and avatar shape — so styles can be compared before picking.
class ChatStylePreview extends StatelessWidget {
  const ChatStylePreview({super.key, required this.style});

  final ChatStyle style;

  @override
  Widget build(BuildContext context) {
    final p = style.palette;
    final s = context.spacing;
    return ClipRRect(
      borderRadius: BorderRadius.circular(context.radii.md),
      // Styles share the chat background; the preview shows the bubbles.
      child: ColoredBox(
        color: p.background,
        child: Padding(
          padding: EdgeInsets.all(s.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Separator(style: style),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Avatar(style: style),
                  SizedBox(width: s.sm),
                  _Bubble(style: style, mine: false, lines: const [1, 0.6]),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Bubble(style: style, mine: true, lines: const [0.8]),
                  if (style.ownAvatar) ...[
                    SizedBox(width: s.sm),
                    _Avatar(style: style),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bubble corners at preview scale: the style's radius, shrunk to fit.
double _radius(ChatStyle style, double height) =>
    style.radius.clamp(0, height / 2);

class _Bubble extends StatelessWidget {
  const _Bubble({required this.style, required this.mine, required this.lines});

  final ChatStyle style;
  final bool mine;

  /// Widths of the text lines, as fractions of the longest.
  final List<double> lines;

  @override
  Widget build(BuildContext context) {
    final p = style.palette;
    final s = context.spacing;
    final ink = (mine ? p.outgoingText : p.incomingText).withValues(
      alpha: 0.55,
    );
    final border = mine ? p.outgoingBorder : p.incomingBorder;
    final width = s.xl6 * 1.6;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.sm),
      decoration: BoxDecoration(
        color: mine ? p.outgoingBubble : p.incomingBubble,
        borderRadius: BorderRadius.circular(_radius(style, s.xl6)),
        border: border == null ? null : Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, f) in lines.indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : s.xs),
              child: Container(
                width: width * f,
                height: s.sm,
                decoration: BoxDecoration(
                  color: ink,
                  borderRadius: BorderRadius.circular(s.sm),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.style});

  final ChatStyle style;

  @override
  Widget build(BuildContext context) {
    final size = context.spacing.xl4;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: style.palette.incomingMeta.withValues(alpha: 0.45),
        shape: style.avatarShape == ChatAvatarShape.circle
            ? BoxShape.circle
            : BoxShape.rectangle,
        borderRadius: style.avatarShape == ChatAvatarShape.circle
            ? null
            : BorderRadius.circular(context.radii.sm),
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator({required this.style});

  final ChatStyle style;

  @override
  Widget build(BuildContext context) {
    final p = style.palette;
    final s = context.spacing;
    final label = Container(
      width: s.xl6,
      height: s.sm,
      decoration: BoxDecoration(
        color: p.separatorText.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(s.sm),
      ),
    );
    return switch (style.separator) {
      ChatSeparatorStyle.pill => Container(
        padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.xs),
        decoration: BoxDecoration(
          color: p.separatorFill ?? p.incomingBubble,
          borderRadius: BorderRadius.circular(s.lg),
        ),
        child: label,
      ),
      ChatSeparatorStyle.plain => label,
      ChatSeparatorStyle.hairline => Row(
        children: [
          Expanded(
            child: Divider(color: p.separatorText.withValues(alpha: 0.3)),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: s.sm),
            child: label,
          ),
          Expanded(
            child: Divider(color: p.separatorText.withValues(alpha: 0.3)),
          ),
        ],
      ),
    };
  }
}
