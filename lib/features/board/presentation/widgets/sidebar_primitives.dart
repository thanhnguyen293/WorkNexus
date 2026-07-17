import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Uppercase heading above a sidebar section.
class SidebarSectionLabel extends StatelessWidget {
  const SidebarSectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.spacing.xs,
        context.spacing.none,
        context.spacing.xs,
        context.spacing.md,
      ),
      child: Text(
        text.toUpperCase(),
        style: context.typography.labelLoose.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
    );
  }
}

/// A tappable sidebar row with leading glyph, label and a trailing count.
class SidebarNavRow extends StatelessWidget {
  const SidebarNavRow({
    super.key,
    required this.leading,
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
    this.height = 31,
  });
  final Widget leading;
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.radii.md),
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
        decoration: BoxDecoration(
          color: active ? c.selectionFill : Colors.transparent,
          borderRadius: BorderRadius.circular(context.radii.md),
        ),
        child: Row(
          children: [
            SizedBox(width: 18, child: Center(child: leading)),
            SizedBox(width: context.spacing.md),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: context.typography.secondary.copyWith(
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? c.textPrimary : c.textSecondary,
                ),
              ),
            ),
            Text(
              '$count',
              style: context.typography.monoSm.copyWith(color: c.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
