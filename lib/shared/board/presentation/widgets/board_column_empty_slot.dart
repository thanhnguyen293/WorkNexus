import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// An intentional, clean empty placeholder slot rendered when a Kanban column
/// contains zero tickets. Fills the remaining column space with a subtle border
/// and muted icon/label, providing an obvious drop target zone.
class BoardColumnEmptySlot extends StatelessWidget {
  const BoardColumnEmptySlot({super.key, this.highlighted = false});

  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final borderColor = highlighted ? c.accent : c.border;
    final bgColor = highlighted ? c.selectionFill : c.surfaceSubtle;

    return Padding(
      padding: EdgeInsets.fromLTRB(s.md, s.md, s.md, s.lg),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(context.radii.md),
          border: Border.all(
            color: borderColor,
            width: context.borders.hairline,
          ),
        ),
        padding: EdgeInsets.all(s.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.inbox300,
              size: context.sizes.iconLg,
              color: highlighted ? c.accent : c.textTertiary,
            ),
            SizedBox(height: s.sm),
            Text(
              l.noItems,
              textAlign: TextAlign.center,
              style: context.typography.caption.copyWith(
                color: highlighted ? c.textSecondary : c.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
