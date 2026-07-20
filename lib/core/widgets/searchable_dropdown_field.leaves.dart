part of 'searchable_dropdown_field.dart';

/// The search input pinned to the top of the popover.
class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
    required this.onKey,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onChanged;
  final KeyEventResult Function(FocusNode, KeyEvent) onKey;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final spacing = context.spacing;
    return Padding(
      padding: EdgeInsets.all(spacing.md),
      child: Focus(
        onKeyEvent: onKey,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          style: context.typography.body.copyWith(color: c.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: c.surfaceSubtle,
            hintText: hint,
            hintStyle: context.typography.body.copyWith(color: c.textTertiary),
            prefixIcon: Icon(Icons.search, size: 18, color: c.textTertiary),
            prefixIconConstraints: BoxConstraints(minWidth: spacing.xl6),
            contentPadding: EdgeInsets.symmetric(vertical: spacing.lg),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.radii.md),
              borderSide: BorderSide(color: c.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.radii.md),
              borderSide: BorderSide(color: c.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.radii.md),
              borderSide: BorderSide(color: c.accent),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single selectable row in the popover list.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.highlighted,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final spacing = context.spacing;
    final Color? fill = selected
        ? c.selectionFill
        : highlighted
        ? c.mixT(c.textPrimary, 0.05)
        : null;
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
                      color: selected ? c.accent : c.textPrimary,
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                if (selected) Icon(Icons.check, size: 16, color: c.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
