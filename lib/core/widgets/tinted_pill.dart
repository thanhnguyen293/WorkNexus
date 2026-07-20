import 'package:flutter/material.dart';

import '../theme/app_borders.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/semantic.dart';
import '../util/zentao_labels.dart';

/// A compact tinted pill (optional leading icon + label), tinted from [color].
/// The shared building block for status/severity/meta chips in the detail panel.
class TintedPill extends StatelessWidget {
  const TintedPill({
    super.key,
    required this.color,
    required this.label,
    this.icon,
    this.pill = false,
  });

  final Color color;
  final String label;
  final IconData? icon;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.sm,
        vertical: context.spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: c.mixT(color, 0.15),
        borderRadius: BorderRadius.circular(
          pill ? context.radii.pill : context.radii.md,
        ),
        border: context.borders.showOutline
            ? Border.all(color: c.mixT(color, 0.40))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            SizedBox(width: context.spacing.xs),
          ],
          Text(
            label,
            style: context.typography.badge.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// ZenTao severity tag (`S1 · Critical`), colored by severity. Renders nothing
/// for an unknown/absent severity.
class SeverityTag extends StatelessWidget {
  const SeverityTag(this.severity, {super.key});
  final int? severity;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = severityColor(c, severity);
    final name = zentaoSeverityLabel(severity);
    if (color == null || name == null) return const SizedBox.shrink();
    return TintedPill(color: color, label: 'S$severity · $name');
  }
}
