import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Renders a unified-diff hunk as colour-tinted monospace lines (added = green,
/// removed = red, hunk header = accent), horizontally scrollable for long lines.
class UnifiedDiffView extends StatelessWidget {
  const UnifiedDiffView(this.diff, {super.key});

  final String diff;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lines = diff.split('\n');
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: context.spacing.sm),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.sm),
        border: Border.all(color: c.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: IntrinsicWidth(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final line in lines) _DiffLine(line)],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiffLine extends StatelessWidget {
  const _DiffLine(this.line);

  final String line;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isAdd = line.startsWith('+') && !line.startsWith('+++');
    final isDel = line.startsWith('-') && !line.startsWith('---');
    final isHunk = line.startsWith('@@');
    final bg = isAdd
        ? c.mixT(c.success, 0.14)
        : isDel
        ? c.mixT(c.error, 0.14)
        : Colors.transparent;
    final fg = isAdd
        ? c.success
        : isDel
        ? c.error
        : isHunk
        ? c.accent
        : c.textSecondary;
    return Container(
      color: bg,
      padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
      child: Text(
        line.isEmpty ? ' ' : line,
        style: context.typography.mono.copyWith(color: fg),
      ),
    );
  }
}
