import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import 'chat_style.dart';
import 'chat_wallpaper.dart';

/// A centered date or time separator in the chat style's look: a pill
/// (Telegram, Zalo), plain text (Messenger, WeChat) or text between hairlines.
/// Over a picture background (pattern or image) plain and hairline
/// separators become a dark translucent pill, or they would not read.
class ChatSeparator extends ConsumerWidget {
  const ChatSeparator({super.key, required this.style, required this.label});

  final ChatStyle style;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = style.palette;
    final onPicture = ref.watch(
      appSettingsProvider.select(
        (s) => chatWallpaperIsPicture(s.chatWallpaper),
      ),
    );
    final ownPill = style.separator == ChatSeparatorStyle.pill;
    final scrimPill = onPicture && !ownPill;
    final text = Text(
      label,
      style: context.typography.captionStrong.copyWith(
        color: scrimPill ? context.colors.onScrim : p.separatorText,
      ),
    );
    final Widget child = switch (style.separator) {
      _ when ownPill || scrimPill => DecoratedBox(
        decoration: BoxDecoration(
          color: scrimPill
              ? context.colors.scrim.withValues(alpha: 0.45)
              : p.separatorFill,
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
      ChatSeparatorStyle.plain || ChatSeparatorStyle.pill => text,
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
