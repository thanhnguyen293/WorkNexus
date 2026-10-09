import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/domain/entities/workspace.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// The anchored dropdown card: workspace rows plus the "New workspace…" action.
class WorkspacePickerPopover extends StatelessWidget {
  const WorkspacePickerPopover({
    super.key,
    required this.link,
    required this.fieldWidth,
    required this.workspaces,
    required this.selectedId,
    required this.labelOf,
    required this.newLabel,
    required this.onClose,
    required this.onSelect,
    required this.onSelectNew,
  });

  final LayerLink link;
  final double fieldWidth;
  final List<Workspace> workspaces;
  final String? selectedId;
  final String Function(Workspace) labelOf;
  final String newLabel;
  final VoidCallback onClose;
  final ValueChanged<String?> onSelect;
  final VoidCallback onSelectNew;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final spacing = context.spacing;
    final card = Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(context.radii.lg),
          border: Border.all(color: c.border),
          boxShadow: [
            BoxShadow(
              color: c.mixT(c.scrim, 0.18),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView(
                  padding: EdgeInsets.all(spacing.xs),
                  shrinkWrap: true,
                  children: [
                    for (final w in workspaces)
                      _OptionRow(
                        label: labelOf(w),
                        selected: w.id == selectedId,
                        onTap: () => onSelect(w.id),
                      ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, thickness: 1, color: c.border),
            Padding(
              padding: EdgeInsets.all(spacing.xs),
              child: _OptionRow(
                label: newLabel,
                selected: false,
                isAction: true,
                onTap: onSelectNew,
              ),
            ),
          ],
        ),
      ),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onClose,
          ),
        ),
        CompositedTransformFollower(
          link: link,
          targetAnchor: Alignment.bottomLeft,
          offset: Offset(0, spacing.xs),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: fieldWidth, child: card),
          ),
        ),
      ],
    );
  }
}

/// A single selectable row in the workspace popover. [isAction] renders the
/// "New workspace…" entry in the accent color.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.isAction = false,
  });

  final String label;
  final bool selected;
  final bool isAction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final spacing = context.spacing;
    final Color? fill = selected ? c.selectionFill : null;
    final Color textColor = isAction
        ? c.accent
        : selected
        ? c.accent
        : c.textPrimary;
    return Padding(
      padding: EdgeInsets.only(bottom: spacing.xxs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(context.radii.sm),
          child: Container(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(context.radii.sm),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: spacing.lg,
              vertical: spacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.body.copyWith(
                      color: textColor,
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                if (selected)
                  Icon(PhosphorIconsLight.check, size: 16, color: c.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
