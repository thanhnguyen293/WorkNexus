import 'package:flutter/material.dart';

import '../../../../core/domain/value_objects/priority.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Circular numbered indicator (①, ②, ③, ④) for ZenTao ticket priority.
class ZenTaoPriorityBadge extends StatelessWidget {
  const ZenTaoPriorityBadge({
    super.key,
    required this.priority,
    this.size = 20.0,
  });

  final Priority priority;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (symbol, color) = switch (priority) {
      Priority.urgent => ('①', c.error),
      Priority.high => ('②', c.warning),
      Priority.medium => ('③', c.accent),
      Priority.low => ('④', c.textTertiary),
    };

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        symbol,
        style: context.typography.monoXs.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          height: 1.0,
        ),
      ),
    );
  }
}
