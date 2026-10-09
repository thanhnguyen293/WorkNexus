import 'package:flutter/material.dart';

import '../../../../core/domain/value_objects/priority.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/util/zentao_labels.dart';

/// What a 1–4 level means, which decides its colors and labels.
enum EditorLevel { severity, priority }

/// A pick of 1–4 (severity or priority) as a row of chips tinted like the
/// board's severity and priority tags; the picked one is filled.
class EditorLevelInput extends StatelessWidget {
  const EditorLevelInput({
    super.key,
    required this.level,
    required this.value,
    required this.onChanged,
  });

  final EditorLevel level;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return Row(
      children: [
        for (var i = 1; i <= 4; i++) ...[
          if (i > 1) SizedBox(width: s.sm),
          Expanded(
            child: _Chip(
              label: _label(i),
              color: _color(context.colors, i),
              selected: value == i,
              onTap: () => onChanged(i),
            ),
          ),
        ],
      ],
    );
  }

  String _label(int i) => switch (level) {
    EditorLevel.severity => zentaoSeverityLabel(i) ?? 'S$i',
    EditorLevel.priority => 'Pri $i',
  };

  Color _color(AppColors c, int i) => switch (level) {
    EditorLevel.severity => severityColor(c, i) ?? c.textTertiary,
    EditorLevel.priority => priorityColor(c, Priority.fromLevel(i - 1)),
  };
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final radius = BorderRadius.circular(context.radii.md);
    return Material(
      color: selected ? c.mixT(color, 0.16) : c.surfaceSubtle,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: selected ? c.mixT(color, 0.6) : c.border),
      ),
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: s.xs, vertical: s.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: s.sm,
                height: s.sm,
                decoration: BoxDecoration(
                  color: selected ? color : c.mixT(color, 0.5),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: s.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.badge.copyWith(
                    color: selected ? color : c.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
