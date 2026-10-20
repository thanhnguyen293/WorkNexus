import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_count_badge.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/derive_board_facets.dart';
import '../providers/board_providers.dart';
import 'filter_facet_groups.dart';
import 'filter_popover_anchor.dart';

/// The toolbar's Filters button with its advanced-filter popover; renders
/// nothing when the board has nothing to filter by.
class FiltersButton extends ConsumerWidget {
  const FiltersButton({
    super.key,
    this.compact = false,
    this.statusOption,
    this.catalog,
    this.onPick,
    this.enabled = true,
  });

  /// Leaves the label off (a narrow toolbar).
  final bool compact;

  /// How a facet status option is drawn (see [FacetFilterGroups.statusOption]).
  final FacetStatusOption? statusOption;

  /// Every choice of each dimension, from the tool that owns the board (see
  /// [BoardFacetCatalog]); without it the options are what the tickets carry.
  final BoardFacetCatalog? catalog;

  /// Called after each option the user picks or drops — the owning board
  /// moves to its All view, so a filter applies to every ticket.
  final VoidCallback? onPick;

  /// Off where the board's view is a filter of its own (Related to me): the
  /// button is greyed out and the popover closes.
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(filterHasGroupsProvider)) return const SizedBox.shrink();
    if (!enabled && ref.watch(advFilterOpenProvider)) {
      // Outside the build phase: providers must not change while widgets build.
      Future.microtask(
        () => ref.read(advFilterOpenProvider.notifier).state = false,
      );
    }
    final count = ref.watch(
      filterStateProvider.select((f) => f.activeTokenCount),
    );
    return FilterPopoverAnchor(
      statusOption: statusOption,
      catalog: catalog,
      onPick: onPick,
      child: _FiltersButtonFace(
        count: count,
        compact: compact,
        onTap: enabled
            ? () => ref.read(advFilterOpenProvider.notifier).update((v) => !v)
            : null,
      ),
    );
  }
}

class _FiltersButtonFace extends StatelessWidget {
  const _FiltersButtonFace({
    required this.count,
    required this.onTap,
    required this.compact,
  });

  final int count;

  /// Null greys the button out.
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final active = count > 0;
    final enabled = onTap != null;
    final color = !enabled
        ? c.textTertiary
        : active
        ? c.accent
        : c.textSecondary;
    return HoverSurface(
      onTap: onTap,
      enabled: enabled,
      height: context.sizes.controlMd,
      padding: EdgeInsets.symmetric(horizontal: compact ? s.md : s.lg),
      color: active ? c.selectionFill : c.surface,
      borderRadius: BorderRadius.circular(context.radii.md),
      border: context.cardBorder,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? LucideIcons.funnel500 : LucideIcons.funnel300,
            size: context.sizes.iconMd,
            color: color,
          ),
          if (!compact) ...[
            SizedBox(width: s.sm),
            Text(
              l.filters,
              style: context.typography.bodySm.copyWith(
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
          if (active) ...[
            SizedBox(width: s.sm),
            AppCountBadge(count, active: true),
          ],
        ],
      ),
    );
  }
}
