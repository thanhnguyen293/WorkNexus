import 'package:flutter/material.dart';

import 'filter_chip.dart';
import 'filter_dropdown_group.dart';

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

/// A filter group drawn by how many [options] it has: a wrap of chips to tap
/// while it is short, a [FilterDropdownGroup] once it holds more than
/// [dropdownThreshold] — a product's members run to dozens of names, and a
/// wrap of them buries the rest of the filters.
class FilterOptionsGroup extends StatelessWidget {
  const FilterOptionsGroup({
    required this.label,
    required this.options,
    this.dropdownThreshold = 8,
    super.key,
  });

  final String label;
  final List<FilterChipOption> options;

  /// Option count above which the group is a dropdown.
  final int dropdownThreshold;

  @override
  Widget build(BuildContext context) {
    // Same rule as FilterGroup: a single option can't filter anything.
    if (options.length <= 1) return const SizedBox.shrink();
    if (options.length > dropdownThreshold) {
      return FilterDropdownGroup(label: label, options: options);
    }
    return FilterGroup(
      label: label,
      children: [
        for (final o in options)
          FilterOptionChip(
            label: o.label,
            active: o.active,
            onTap: o.onTap,
            dotColor: o.dotColor,
            count: o.count,
          ),
      ],
    );
  }
}
