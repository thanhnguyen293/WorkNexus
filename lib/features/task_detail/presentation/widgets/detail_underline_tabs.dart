import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hover_surface.dart';

/// The detail panels' tab strip: text tabs with an accent underline on the
/// active one, over a hairline. Shared by the standard panel (Original /
/// Translation) and the two-pane MR / PR detail (Overview / Commits / Changes)
/// so both read as one control.
class DetailUnderlineTabs<T> extends StatelessWidget {
  const DetailUnderlineTabs({
    super.key,
    required this.labels,
    required this.current,
    required this.onSelect,
  });

  final Map<T, String> labels;
  final T current;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border(bottom: context.hairlineSide)),
      padding: EdgeInsets.symmetric(horizontal: context.spacing.xl),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final e in labels.entries)
              _UnderlineTab(
                label: e.value,
                selected: e.key == current,
                onTap: () => onSelect(e.key),
              ),
          ],
        ),
      ),
    );
  }
}

class _UnderlineTab extends StatelessWidget {
  const _UnderlineTab({
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
    return HoverSurface(
      onTap: onTap,
      selected: selected,
      height: context.sizes.controlLg,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: context.spacing.xl),
      border: Border(
        bottom: BorderSide(
          color: selected ? c.accent : Colors.transparent,
          width: context.borders.thick,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: context.typography.secondary.copyWith(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? c.textPrimary : c.textSecondary,
        ),
      ),
    );
  }
}
