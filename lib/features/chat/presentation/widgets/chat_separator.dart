import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import 'chat_style.dart';

/// A centered date or time separator in the chat style's look: a pill
/// (Telegram, Zalo), plain text (Messenger, WeChat) or text between hairlines.
class ChatSeparator extends StatelessWidget {
  const ChatSeparator({super.key, required this.style, required this.label});

  final ChatStyle style;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = style.palette;
    final text = Text(
      label,
      style: context.typography.captionStrong.copyWith(color: p.separatorText),
    );
    final Widget child = switch (style.separator) {
      ChatSeparatorStyle.pill => DecoratedBox(
        decoration: BoxDecoration(
          color: p.separatorFill,
          borderRadius: BorderRadius.circular(context.radii.pill),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.xl,
            vertical: context.spacing.xs,
          ),
          child: text,
        ),
      ),
      ChatSeparatorStyle.plain => text,
      ChatSeparatorStyle.hairline => Row(
        children: [
          Expanded(child: Divider(color: context.colors.border, height: 1)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spacing.xl),
            child: text,
          ),
          Expanded(child: Divider(color: context.colors.border, height: 1)),
        ],
      ),
    };
    return Padding(
      padding: EdgeInsets.only(
        top: context.spacing.xl4,
        bottom: context.spacing.xs,
      ),
      child: Center(child: child),
    );
  }
}
