import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import 'chat_side_panel_frame.dart';

/// A card that opens a sub-panel of the info: icon, label, count, chevron.
class ChatInfoPanelLink extends StatelessWidget {
  const ChatInfoPanelLink({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String label;

  /// Null while unknown.
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return ChatPanelCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: s.xl),
        visualDensity: VisualDensity.compact,
        horizontalTitleGap: s.lg,
        minLeadingWidth: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.radii.lg),
        ),
        // The details rows' size, so the card icons line up as one set.
        leading: Icon(icon, size: context.sizes.iconLg, color: c.accent),
        title: Text(
          label,
          style: context.typography.bodyStrong.copyWith(color: c.textPrimary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (count case final n?)
              Text(
                '$n',
                style: context.typography.bodyStrong.copyWith(
                  color: c.textSecondary,
                ),
              ),
            Icon(
              LucideIcons.chevronRight300,
              size: context.sizes.iconLg,
              color: c.textTertiary,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
