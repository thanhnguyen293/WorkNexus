import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_typography.dart';

class TaskFormModeToggle extends StatelessWidget {
  const TaskFormModeToggle({
    super.key,
    required this.isLite,
    required this.onToggle,
  });

  final bool isLite;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.pill),
        border: Border.all(color: c.border),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillSegment(
            label: 'Lite Mode',
            selected: isLite,
            onTap: () => onToggle(true),
          ),
          _PillSegment(
            label: 'Full Mode',
            selected: !isLite,
            onTap: () => onToggle(false),
          ),
        ],
      ),
    );
  }
}

class _PillSegment extends StatelessWidget {
  const _PillSegment({
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
          color: selected ? c.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(context.radii.pill),
        ),
        child: Text(
          label,
          style: context.typography.captionStrong.copyWith(
            color: selected ? c.onAccent : c.textSecondary,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
