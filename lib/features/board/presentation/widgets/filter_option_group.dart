import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import 'filter_chip.dart';

/// One choice in a filter group, as data rather than a built widget — a group
/// can only filter its own options if it can read their labels.
class FilterChipOption {
  const FilterChipOption({
    required this.label,
    required this.active,
    required this.onTap,
    this.dotColor,
    this.count,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? dotColor;
  final int? count;
}

/// A [FilterGroup] that grows a search box once it holds more options than a
/// person can scan — the assignee list on a busy product runs to dozens of
/// names, and hunting for one in a wrap of chips is the slow part.
///
/// Options already selected stay visible no matter what the query is, so a
/// search can never hide (and strand) an active filter.
class SearchableFilterGroup extends StatefulWidget {
  const SearchableFilterGroup({
    required this.label,
    required this.options,
    this.searchThreshold = 8,
    super.key,
  });

  final String label;
  final List<FilterChipOption> options;

  /// Option count above which the search box appears.
  final int searchThreshold;

  @override
  State<SearchableFilterGroup> createState() => _SearchableFilterGroupState();
}

class _SearchableFilterGroupState extends State<SearchableFilterGroup> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<FilterChipOption> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return widget.options
        .where((o) => o.active || o.label.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // Same rule as FilterGroup: a single option can't filter anything.
    if (widget.options.length <= 1) return const SizedBox.shrink();
    if (widget.options.length <= widget.searchThreshold) {
      return FilterGroup(
        label: widget.label,
        children: [for (final o in widget.options) _chip(o)],
      );
    }
    final c = context.colors;
    final l = AppL10n.of(context);
    final visible = _visible;
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label.toUpperCase(),
            style: context.typography.label.copyWith(color: c.textTertiary),
          ),
          SizedBox(height: context.spacing.sm),
          _GroupSearchField(
            controller: _controller,
            onChanged: (v) => setState(() => _query = v),
          ),
          SizedBox(height: context.spacing.sm),
          if (visible.isEmpty)
            Text(
              l.filterNoMatches,
              style: context.typography.meta.copyWith(color: c.textTertiary),
            )
          else
            Wrap(
              spacing: context.spacing.sm,
              runSpacing: context.spacing.sm,
              children: [for (final o in visible) _chip(o)],
            ),
        ],
      ),
    );
  }

  Widget _chip(FilterChipOption o) => FilterOptionChip(
    label: o.label,
    active: o.active,
    onTap: o.onTap,
    dotColor: o.dotColor,
    count: o.count,
  );
}

/// The compact in-popover search input. Narrower and quieter than the toolbar's
/// board search so it reads as part of the group, not a second global search.
class _GroupSearchField extends StatelessWidget {
  const _GroupSearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(context.radii.md),
      borderSide: BorderSide(color: c.border),
    );
    return SizedBox(
      height: 28,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: context.typography.meta.copyWith(color: c.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: c.surfaceSubtle,
          hintText: l.filterSearchHint,
          hintStyle: context.typography.meta.copyWith(color: c.textTertiary),
          prefixIcon: Icon(Icons.search, size: 14, color: c.textTertiary),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 26,
            minHeight: 26,
          ),
          contentPadding: EdgeInsets.symmetric(
            vertical: context.spacing.xs,
            horizontal: context.spacing.xs,
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: c.accent),
          ),
        ),
      ),
    );
  }
}
