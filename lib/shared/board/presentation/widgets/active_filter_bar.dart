import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/derive_board_facets.dart';
import '../../domain/usecases/is_saved_filter_applied.dart';
import '../providers/board_providers.dart';
import '../providers/saved_filter_providers.dart';
import 'facet_labels.dart';
import 'filter_facet_groups.dart';

/// The filters in effect, under a board's toolbar: the saved filter they
/// match (highlighted), then one chip per picked group ("Severity: Critical,
/// Major") whose ✕ drops that group, and Clear all. Nothing when no filter is
/// picked, so an unfiltered board keeps its height.
class ActiveFilterBar extends ConsumerWidget {
  const ActiveFilterBar({super.key, this.catalog, this.statusOption});

  /// The owning tool's choices, so a picked value is named as the popover
  /// names it (see [FacetFilterGroups.catalog]).
  final BoardFacetCatalog? catalog;
  final FacetStatusOption? statusOption;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final f = ref.watch(filterStateProvider);
    if (f.activeTokenCount == 0) return const SizedBox.shrink();
    final ctrl = ref.read(filterStateProvider.notifier);
    final presets = ref.watch(savedFiltersProvider).value ?? const [];
    final applied = presets
        .where((p) => const IsSavedFilterApplied()(p, f))
        .firstOrNull;
    final facets = ref.watch(boardFacetsProvider(catalog));

    String nameOf(BoardFacetGroup g, BoardFacetOption o) {
      final status = statusOption;
      if (g.kind == BoardFacetKind.status && status != null) {
        return status(context, o, active: true, onTap: () {}).label;
      }
      return o.label ?? facetLabel(l, g.kind, o.value);
    }

    final s = context.spacing;
    return Padding(
      padding: EdgeInsets.fromLTRB(s.xl, 0, s.xl, s.md),
      child: Wrap(
        spacing: s.sm,
        runSpacing: s.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (applied != null)
            _ActiveChip(
              value: applied.name,
              highlighted: true,
              // A saved filter is the whole set of chips: removing it clears
              // them all.
              onRemove: ctrl.clearAll,
            ),
          for (final g in facets.groups)
            if (g.options.where((o) => facetActive(f, g.kind, o.value))
                case final picked when picked.isNotEmpty)
              _ActiveChip(
                label: facetHeader(l, g.kind),
                value: picked.map((o) => nameOf(g, o)).join(', '),
                onRemove: () => ctrl.clearFacet(g.kind),
              ),
          AppButton.textNeutral(
            size: AppButtonSize.small,
            onPressed: ctrl.clearAll,
            child: Text(l.clearAllFilters),
          ),
        ],
      ),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  const _ActiveChip({
    required this.value,
    required this.onRemove,
    this.label,
    this.highlighted = false,
  });

  final String? label;
  final String value;
  final VoidCallback onRemove;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final type = context.typography.meta;
    final ink = highlighted ? c.accent : c.textPrimary;
    return Container(
      height: context.sizes.controlSm,
      padding: EdgeInsets.only(left: context.spacing.lg),
      decoration: BoxDecoration(
        color: highlighted ? c.selectionFill : c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.pill),
        border: context.borders.showOutline
            ? Border.all(color: c.border)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label case final label?)
            Text('$label  ', style: type.copyWith(color: c.textSecondary)),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.sizes.toolPaneWidth),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.copyWith(color: ink, fontWeight: FontWeight.w500),
            ),
          ),
          AppIconButton(
            icon: LucideIcons.x300,
            tooltip: AppL10n.of(context).removeFilter,
            size: AppIconButtonSize.small,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
