import 'package:flutter/material.dart';

import '../theme/app_borders.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Segments filling the row, each as wide as its label needs, the picked
/// one raised as a card.
class QuickSettingsSegmented<T> extends StatelessWidget {
  const QuickSettingsSegmented({
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    // Measured in the bold "picked" style, so a segment never reflows or
    // truncates when it becomes the selected one.
    final style = context.typography.bodySmStrong;
    final scaler = MediaQuery.textScalerOf(context);
    int flexOf(String label) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return (width + context.spacing.xl3).round();
    }

    return Container(
      padding: EdgeInsets.all(context.spacing.xxs),
      decoration: BoxDecoration(
        color: context.colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.md),
      ),
      child: Row(
        children: [
          for (final entry in options.entries)
            Expanded(
              // Width follows the label, so "Default" beside "Small" gets
              // the room it needs instead of an ellipsis.
              flex: flexOf(entry.value),
              child: _Segment(
                label: entry.value,
                selected: entry.key == value,
                onTap: () => onChanged(entry.key),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
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
    final radius = BorderRadius.circular(context.radii.sm);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? c.surface : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: selected ? context.hairlineSide : BorderSide.none,
        ),
        child: InkWell(
          mouseCursor: WidgetStateMouseCursor.clickable,
          customBorder: RoundedRectangleBorder(borderRadius: radius),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.spacing.xs,
              vertical: context.spacing.sm,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  (selected
                          ? context.typography.bodySmStrong
                          : context.typography.bodySm)
                      .copyWith(
                        color: selected ? c.textPrimary : c.textSecondary,
                      ),
            ),
          ),
        ),
      ),
    );
  }
}
