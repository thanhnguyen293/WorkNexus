import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';

/// The accent "Show N empty fields" / "Hide empty fields" link under the
/// classification rows.
class EmptyFieldsToggle extends StatelessWidget {
  const EmptyFieldsToggle({
    super.key,
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Align(
      alignment: Alignment.centerLeft,
      child: HoverRegion(
        // HoverSurface makes the link focusable and keyboard-activatable; the
        // underline stays the hover cue, so it paints no tint.
        builder: (context, hovered, _) => HoverSurface(
          onTap: onTap,
          tintOnHover: false,
          borderRadius: BorderRadius.circular(context.radii.sm),
          padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
          child: Text(
            expanded
                ? AppL10n.of(context).hideEmptyFields
                : AppL10n.of(context).showEmptyFields(count),
            style: context.typography.caption.copyWith(
              color: c.accent,
              // A text link underlines on hover.
              decoration: hovered ? TextDecoration.underline : null,
              decorationColor: c.accent,
            ),
          ),
        ),
      ),
    );
  }
}
