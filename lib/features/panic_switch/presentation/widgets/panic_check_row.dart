import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// A tickable row of the "Thầy vô" lists (apps to open, allowed senders): the
/// whole row toggles.
class PanicCheckRow extends StatelessWidget {
  const PanicCheckRow({
    super.key,
    required this.label,
    required this.picked,
    required this.onToggle,
    this.detail,
  });

  final String label;
  final String? detail;
  final bool picked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: onToggle,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: s.xs, vertical: s.xxs),
        child: Row(
          spacing: s.md,
          children: [
            Checkbox(value: picked, onChanged: (_) => onToggle()),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.body.copyWith(color: c.textPrimary),
              ),
            ),
            if (detail case final detail?)
              Text(
                detail,
                style: context.typography.caption.copyWith(
                  color: c.textTertiary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
