import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/hover_surface.dart';
import 'chat_bubble_theme.dart';

/// A small bordered square with an icon, beside a file in a bubble (show in
/// folder, save as).
class ChatFileActionButton extends StatelessWidget {
  const ChatFileActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final ink = ChatBubbleTheme.of(context).meta;
    return Tooltip(
      message: tooltip,
      child: HoverSurface(
        width: s.xl5 + s.xs,
        height: s.xl5 + s.xs,
        onTap: onPressed,
        borderRadius: BorderRadius.circular(context.radii.sm),
        border: Border.all(color: ink.withValues(alpha: 0.45)),
        hoverBorder: Border.all(color: ink),
        hoverColor: context.colors.hoverFill,
        child: Center(
          child: Icon(icon, size: s.xl2, color: ink),
        ),
      ),
    );
  }
}
