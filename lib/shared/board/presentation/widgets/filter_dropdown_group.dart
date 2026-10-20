import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_count_badge.dart';
import '../../../../core/widgets/app_search_field.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';
import 'filter_option_group.dart';

/// A filter group too long for a wrap of chips (a product's members), as a
/// field that names what is picked and opens, in place, into a searchable
/// checklist. In place rather than in a pop-up of its own: the filter popover
/// closes on a tap outside it, and a second pop-up would be outside.
///
/// Options already picked stay in the list whatever the query, so a search
/// never hides (and strands) an active filter.
class FilterDropdownGroup extends StatefulWidget {
  const FilterDropdownGroup({
    super.key,
    required this.label,
    required this.options,
    this.dense = false,
  });

  final String label;
  final List<FilterChipOption> options;

  /// Leaves off the space a group keeps below itself (one of several in a
  /// box of their own).
  final bool dense;

  @override
  State<FilterDropdownGroup> createState() => _FilterDropdownGroupState();
}

class _FilterDropdownGroupState extends State<FilterDropdownGroup> {
  final _search = TextEditingController();
  bool _open = false;
  String _query = '';

  /// The list's height before it scrolls: about eight rows.
  static const _maxListHeight = 240.0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<FilterChipOption> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return [
      for (final o in widget.options)
        if (o.active || o.label.toLowerCase().contains(q)) o,
    ];
  }

  void _toggleOpen() => setState(() {
    _open = !_open;
    if (!_open) {
      _search.clear();
      _query = '';
    }
  });

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final l = AppL10n.of(context);
    final picked = [
      for (final o in widget.options)
        if (o.active) o,
    ];
    final visible = _visible;
    return Padding(
      padding: EdgeInsets.only(bottom: widget.dense ? 0 : s.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(title: widget.label),
          SizedBox(height: s.xs),
          _DropdownField(picked: picked, open: _open, onTap: _toggleOpen),
          if (_open) ...[
            SizedBox(height: s.sm),
            AppSearchField(
              controller: _search,
              hint: l.filterSearchHint,
              height: context.sizes.controlSm,
              onChanged: (v) => setState(() => _query = v),
            ),
            SizedBox(height: s.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _maxListHeight),
              child: visible.isEmpty
                  ? Padding(
                      padding: EdgeInsets.all(s.sm),
                      child: Text(
                        l.filterNoMatches,
                        style: context.typography.meta.copyWith(
                          color: context.colors.textTertiary,
                        ),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children: [for (final o in visible) _OptionRow(o)],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The closed dropdown: the picked options' names (or "Any"), how many, and
/// which way it opens.
class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.picked,
    required this.open,
    required this.onTap,
  });

  final List<FilterChipOption> picked;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final any = picked.isEmpty;
    return HoverSurface(
      onTap: onTap,
      height: context.sizes.controlMd,
      padding: EdgeInsets.symmetric(horizontal: s.md),
      color: any ? c.surface : c.selectionFill,
      borderRadius: BorderRadius.circular(context.radii.md),
      border: context.cardBorder,
      child: Row(
        spacing: s.sm,
        children: [
          Expanded(
            child: Text(
              any
                  ? AppL10n.of(context).filterAnyOption
                  : picked.map((o) => o.label).join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.bodySm.copyWith(
                color: any ? c.textTertiary : c.textPrimary,
              ),
            ),
          ),
          if (!any) AppCountBadge(picked.length, active: true),
          Icon(
            open ? LucideIcons.chevronUp300 : LucideIcons.chevronDown300,
            size: context.sizes.iconSm,
            color: c.textSecondary,
          ),
        ],
      ),
    );
  }
}

/// One option of the open list: a checkbox, its colour dot, its name and how
/// many loaded tickets carry it.
class _OptionRow extends StatelessWidget {
  const _OptionRow(this.option);

  final FilterChipOption option;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final o = option;
    return HoverSurface(
      onTap: o.onTap,
      selected: o.active,
      height: context.sizes.controlSm,
      padding: EdgeInsets.symmetric(horizontal: s.sm),
      borderRadius: BorderRadius.circular(context.radii.sm),
      child: Row(
        spacing: s.sm,
        children: [
          Icon(
            o.active ? LucideIcons.squareCheck300 : LucideIcons.square300,
            size: context.sizes.iconMd,
            color: o.active ? c.accent : c.textTertiary,
          ),
          if (o.dotColor case final dot?)
            SizedBox.square(
              dimension: s.sm,
              child: DecoratedBox(
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
            ),
          Expanded(
            child: Text(
              o.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.bodySm.copyWith(
                color: o.active ? c.textPrimary : c.textSecondary,
              ),
            ),
          ),
          if (o.count case final count?)
            Text(
              '$count',
              style: context.typography.meta.copyWith(color: c.textTertiary),
            ),
        ],
      ),
    );
  }
}
