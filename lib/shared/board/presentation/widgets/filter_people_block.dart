import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../../../l10n/app_localizations.dart';
import 'filter_dropdown_group.dart';
import 'filter_option_group.dart';

/// The filter groups that pick people (assigned to, resolved by, opened by),
/// in one box. A ticket passes them when any one matches, unlike the groups
/// around them, which must all match; so the box says so and an OR stands
/// between its dropdowns.
class FilterPeopleBlock extends StatelessWidget {
  const FilterPeopleBlock({super.key, required this.groups});

  final List<({String label, List<FilterChipOption> options})> groups;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: s.xl),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surfaceSubtle,
          borderRadius: BorderRadius.circular(context.radii.md),
          border: context.cardBorder,
        ),
        child: Padding(
          padding: EdgeInsets.all(s.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                spacing: s.sm,
                children: [
                  AppSectionHeader(title: l.filterPeople),
                  const _OrTag(),
                ],
              ),
              SizedBox(height: s.xxs),
              Text(
                l.filterPeopleAnyHint,
                style: context.typography.meta.copyWith(color: c.textTertiary),
              ),
              SizedBox(height: s.md),
              for (final (i, g) in groups.indexed) ...[
                if (i > 0) const _OrDivider(),
                FilterDropdownGroup(
                  label: g.label,
                  options: g.options,
                  dense: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A hairline with an OR on it, between two of the block's dropdowns.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: s.sm),
      child: Row(
        spacing: s.sm,
        children: [
          Expanded(child: Divider(height: 1, color: context.colors.border)),
          const _OrTag(),
          Expanded(child: Divider(height: 1, color: context.colors.border)),
        ],
      ),
    );
  }
}

class _OrTag extends StatelessWidget {
  const _OrTag();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.selectionFill,
        borderRadius: BorderRadius.circular(context.radii.pill),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xxs),
        child: Text(
          AppL10n.of(context).filterOr,
          style: context.typography.caption.copyWith(
            color: c.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
