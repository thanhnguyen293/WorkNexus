import 'package:flutter/material.dart';

import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/contrast.dart';
import '../../../../core/widgets/hover_surface.dart';
import 'chat_bubble_theme.dart';

const double _kCardMaxWidth = 420;

/// The box of a compact link card inside a message (merge request, ZenTao
/// ticket), shaped like a quote: a tinted block with a bar on its left edge
/// — in the item's state colour ([bar]), else the bubble's quote colour.
class ChatLinkCardFrame extends StatelessWidget {
  const ChatLinkCardFrame({
    super.key,
    required this.onTap,
    required this.child,
    this.bar,
  });

  final VoidCallback onTap;
  final Widget child;
  final Color? bar;

  @override
  Widget build(BuildContext context) {
    final ink = ChatBubbleTheme.of(context);
    final s = context.spacing;
    final radius = BorderRadius.circular(context.radii.sm);
    return Padding(
      padding: EdgeInsets.only(top: s.md),
      child: HoverSurface(
        onTap: onTap,
        constraints: const BoxConstraints(maxWidth: _kCardMaxWidth),
        padding: EdgeInsets.fromLTRB(s.lg, s.md, s.lg, s.md),
        color: ink.quoteFill,
        hoverColor: ink.hoverFill,
        borderRadius: radius,
        border: Border(left: BorderSide(color: bar ?? ink.quoteBar, width: 3)),
        child: child,
      ),
    );
  }
}

/// A span drawn in [color] and bold, for [ChatCardLine] — adjusted to read
/// on the card in every chat style (see [readableOn]).
InlineSpan chatCardStrong(BuildContext context, String text, Color color) {
  final ink = ChatBubbleTheme.of(context);
  return TextSpan(
    text: text,
    style: context.typography.captionStrong.copyWith(
      color: readableOn(color, ink.quoteSurface, towards: ink.text),
    ),
  );
}

/// One caption line of parts joined by ` · `: plain strings in the meta
/// colour, spans as given.
class ChatCardLine extends StatelessWidget {
  const ChatCardLine({super.key, required this.spans});

  final List<Object> spans;

  @override
  Widget build(BuildContext context) {
    final ink = ChatBubbleTheme.of(context);
    final style = context.typography.caption.copyWith(
      color: readableOn(ink.meta, ink.quoteSurface, towards: ink.text),
    );
    final children = <InlineSpan>[];
    for (final (i, part) in spans.indexed) {
      if (i > 0) children.add(const TextSpan(text: ' · '));
      children.add(part is InlineSpan ? part : TextSpan(text: '$part'));
    }
    return Text.rich(
      TextSpan(style: style, children: children),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// A card's title: one bold line.
class ChatCardTitle extends StatelessWidget {
  const ChatCardTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ink = ChatBubbleTheme.of(context);
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.typography.bodyStrong.copyWith(color: ink.text),
    );
  }
}
