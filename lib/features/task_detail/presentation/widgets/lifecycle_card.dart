import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';
import 'detail_field_rows.dart';
import 'detail_fields_card.dart';
import 'detail_region_card.dart';
import 'section_label.dart';

/// A ZenTao ticket's lifecycle dates in the sidebar. They are looked up now
/// and then, so the card starts folded under its heading; nothing shows
/// without [rows].
class LifecycleCard extends StatefulWidget {
  const LifecycleCard({super.key, required this.rows});

  final List<(String, String)> rows;

  @override
  State<LifecycleCard> createState() => _LifecycleCardState();
}

class _LifecycleCardState extends State<LifecycleCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) return const SizedBox.shrink();
    return DetailRegionCard(
      padding: detailSidebarInset(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LifecycleToggle(
            expanded: _expanded,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            DetailFieldRows(
              rows: widget.rows,
              labelWidth: kSidebarLabelWidth,
              alignEnd: true,
            ),
        ],
      ),
    );
  }
}

/// The "Lifecycle" heading as a fold toggle, a chevron showing which way it
/// goes.
class _LifecycleToggle extends StatelessWidget {
  const _LifecycleToggle({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverSurface(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.radii.sm),
      padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
      child: Row(
        children: [
          Expanded(child: SectionLabel(AppL10n.of(context).lifecycle)),
          Icon(
            expanded ? LucideIcons.chevronUp300 : LucideIcons.chevronDown300,
            size: context.typography.secondary.fontSize,
            color: context.colors.textTertiary,
          ),
        ],
      ),
    );
  }
}
