import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class ZenTaoTypeRow extends StatelessWidget {
  const ZenTaoTypeRow({
    super.key,
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.radii.sm),
      child: Container(
        height: 27,
        padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
        decoration: BoxDecoration(
          color: active ? c.selectionFill : Colors.transparent,
          borderRadius: BorderRadius.circular(context.radii.sm),
        ),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: onTap == null ? c.textTertiary : c.accent,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: context.spacing.sm),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: context.typography.mono.copyWith(
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: onTap == null ? c.textTertiary : c.textPrimary,
                ),
              ),
            ),
            Text(
              '$count',
              style: context.typography.monoXs.copyWith(color: c.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
