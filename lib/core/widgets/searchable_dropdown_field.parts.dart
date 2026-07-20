part of 'searchable_dropdown_field.dart';

/// The full-screen overlay: a dismiss barrier plus the anchored popover holding
/// the search box and filtered option list.
class _PopupOverlay<T> extends StatelessWidget {
  const _PopupOverlay({
    required this.link,
    required this.fieldWidth,
    required this.searchController,
    required this.searchFocus,
    required this.searchHint,
    required this.emptyLabel,
    required this.maxListHeight,
    required this.scrollController,
    required this.items,
    required this.selectedValue,
    required this.highlighted,
    required this.labelOf,
    required this.onClose,
    required this.onQueryChanged,
    required this.onKey,
    required this.onSelect,
  });

  final LayerLink link;
  final double fieldWidth;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final String searchHint;
  final String emptyLabel;
  final double maxListHeight;
  final ScrollController scrollController;
  final List<T> items;
  final T? selectedValue;
  final int highlighted;
  final String Function(T item) labelOf;
  final VoidCallback onClose;
  final ValueChanged<String> onQueryChanged;
  final KeyEventResult Function(FocusNode, KeyEvent) onKey;
  final ValueChanged<T> onSelect;

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
            _SearchBox(
              controller: searchController,
              focusNode: searchFocus,
              hint: searchHint,
              onChanged: onQueryChanged,
              onKey: onKey,
            ),
            Divider(height: 1, thickness: 1, color: c.border),
            if (items.isEmpty)
              _EmptyRow(label: emptyLabel)
            else
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxListHeight),
                  child: ListView.builder(
                    controller: scrollController,
                    padding: EdgeInsets.all(spacing.xs),
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = items[i];
                      return _OptionTile(
                        label: labelOf(item),
                        selected: item == selectedValue,
                        highlighted: i == highlighted,
                        onTap: () => onSelect(item),
                      );
                    },
                  ),
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

/// Placeholder row shown when the query matches no options.
class _EmptyRow extends StatelessWidget {
  const _EmptyRow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacing.xl4),
      child: Text(
        label,
        style: context.typography.bodySm.copyWith(
          color: context.colors.textTertiary,
        ),
      ),
    );
  }
}

/// The tap target shown when the popover is closed.
class _ClosedField extends StatelessWidget {
  const _ClosedField({
    required this.label,
    required this.hintText,
    required this.onTap,
  });

  final String? label;
  final String hintText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final spacing = context.spacing;
    final hasValue = label != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.radii.md),
        child: Container(
          decoration: BoxDecoration(
            color: c.surfaceSubtle,
            borderRadius: BorderRadius.circular(context.radii.md),
            border: Border.all(color: c.border),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: spacing.lg,
            vertical: spacing.lg,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hasValue ? label! : hintText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.body.copyWith(
                    color: hasValue ? c.textPrimary : c.textTertiary,
                  ),
                ),
              ),
              Icon(Icons.expand_more, size: 20, color: c.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
