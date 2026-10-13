import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// "Why am I asked?": what confirming the chat server's certificate does, so
/// the step reads as protection rather than an error to click through.
class ChatTrustReasons extends StatelessWidget {
  const ChatTrustReasons({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.chatTrustWhy,
          style: context.typography.captionStrong.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        SizedBox(height: s.md),
        _Reason(icon: LucideIcons.history300, text: l.chatTrustWhyOnce),
        SizedBox(height: s.md),
        _Reason(icon: LucideIcons.shieldAlert300, text: l.chatTrustWhyChange),
        SizedBox(height: s.md),
        _Reason(icon: LucideIcons.userCheck300, text: l.chatTrustWhyCheck),
      ],
    );
  }
}

class _Reason extends StatelessWidget {
  const _Reason({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = context.typography.paragraph.copyWith(color: c.textPrimary);
    // Centres the glyph on the first line of a wrapping paragraph.
    final lineHeight = (style.fontSize ?? 0) * (style.height ?? 1);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: lineHeight,
          child: Icon(icon, size: context.sizes.iconSm, color: c.accent),
        ),
        SizedBox(width: context.spacing.md),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}
