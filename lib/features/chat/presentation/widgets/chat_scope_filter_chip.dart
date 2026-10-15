import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_typography.dart';

/// Scope filter chip for chat search (e.g. All chats vs Current chat).
class ChatScopeFilterChip extends StatelessWidget {
  const ChatScopeFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.radii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? c.accent.withValues(alpha: 0.12) : c.surfaceSubtle,
          borderRadius: BorderRadius.circular(context.radii.pill),
          border: Border.all(
            color: selected ? c.accent : c.border,
            width: context.borders.hairline,
          ),
        ),
        child: Text(
          label,
          style: context.typography.secondary.copyWith(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? c.accent : c.textSecondary,
          ),
        ),
      ),
    );
  }
}
