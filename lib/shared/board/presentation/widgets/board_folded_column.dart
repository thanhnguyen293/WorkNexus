import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';

/// A kanban column folded to a narrow strip: its status [dot], its [label]
/// read sideways and its [badge]. Empty columns fold so the busy ones get
/// the width; a tap opens it, and [highlighted] shows a card dragged over it
/// (it still takes the drop).
class BoardFoldedColumn extends StatelessWidget {
  const BoardFoldedColumn({
    super.key,
    required this.dot,
    required this.label,
    required this.badge,
    required this.onOpen,
    this.highlighted = false,
  });

  final Widget dot;
  final String label;
  final Widget badge;
  final VoidCallback onOpen;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Tooltip(
      message: AppL10n.of(context).boardOpenColumn(label),
      child: HoverSurface(
        onTap: onOpen,
        width: context.sizes.boardColumnFolded,
        color: highlighted ? c.selectionFill : c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.lg),
        border: Border.all(color: highlighted ? c.accent : c.border),
        padding: EdgeInsets.symmetric(vertical: s.lg),
        child: Column(
          spacing: s.md,
          children: [
            dot,
            badge,
            Flexible(
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.bodySmStrong.copyWith(
                    color: c.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
