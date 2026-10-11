part of 'workspace_picker.dart';

const double _kMaxListHeight = 260;

/// The anchored dropdown card: workspace rows plus the "New workspace…" action.
class _WorkspacePopover extends StatelessWidget {
  const _WorkspacePopover({
    required this.link,
    required this.tapGroup,
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
  final Object tapGroup;
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
                constraints: const BoxConstraints(maxHeight: _kMaxListHeight),
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
    return CompositedTransformFollower(
      link: link,
      targetAnchor: Alignment.bottomLeft,
      offset: Offset(0, spacing.xs),
      child: Align(
        alignment: Alignment.topLeft,
        child: TapRegion(
          groupId: tapGroup,
          onTapOutside: (_) => onClose(),
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): onClose,
            },
            child: FocusScope(
              autofocus: true,
              child: SizedBox(width: fieldWidth, child: card),
            ),
          ),
        ),
      ),
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
          mouseCursor: WidgetStateMouseCursor.clickable,
          onTap: onTap,
          borderRadius: BorderRadius.circular(context.radii.sm),
          // Ink, not Container, so the fill sits under the hover highlight.
          child: Ink(
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
                if (isAction) ...[
                  Icon(
                    LucideIcons.plus300,
                    size: context.sizes.iconMd,
                    color: c.accent,
                  ),
                  SizedBox(width: spacing.sm),
                ],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.body.copyWith(
                      color: textColor,
                      fontWeight: selected ? FontWeight.w500 : null,
                    ),
                  ),
                ),
                if (selected)
                  Icon(
                    LucideIcons.check300,
                    size: context.sizes.iconMd,
                    color: c.accent,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
