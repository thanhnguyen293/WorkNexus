import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_count_badge.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_search_field.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';
import '../board_providers.dart';
import '../board_refresh.dart';
import 'board_layout_toggle.dart';
import 'filter_popover_anchor.dart';
import 'new_ticket_button.dart';

/// Whether the advanced-filter popover is open.
final advFilterOpenProvider = StateProvider<bool>((ref) => false);

/// The tap region shared by the Filters button and its popover: a click
/// anywhere else closes the popover, while the button keeps toggling it.
const kFilterPopoverTapGroup = #filterPopover;

/// The top toolbar: search, filters button (hidden when nothing to filter),
/// active tokens, refresh.
class ChromeBar extends ConsumerWidget {
  const ChromeBar({super.key, this.tabs});

  /// The active board's view tabs (All/Unclosed, Issues/MRs…), rendered inline
  /// at the right of the toolbar. Null when the current board has no tabs.
  final Widget? tabs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final filter = ref.watch(filterStateProvider);
    final hasFilters = ref.watch(filterHasGroupsProvider);
    // Only the ZenTao boards have a table layout.
    final layoutToggle = switch (ref.watch(viewModeProvider)) {
      ViewMode.zentaoTasks || ViewMode.zentaoBugs => true,
      _ => false,
    };

    return Container(
      decoration: BoxDecoration(
        // The card colour: set apart from the board canvas below it and from
        // the sidebar's surface beside it.
        color: c.card,
        border: Border(bottom: context.hairlineSide),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.xl2,
        vertical: context.spacing.md,
      ),
      // Wide: the search takes a bounded share of the width (not a flex share,
      // whose unused part would sit empty), the filter tokens the rest, and
      // refresh the far end. Narrow: the tokens give way to the search and the
      // filters button keeps just its icon and count.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < _kNarrowToolbar;
          const search = _SearchBox();
          return Row(
            spacing: context.spacing.lg,
            children: [
              ?tabs,
              if (narrow)
                const Expanded(child: search)
              else
                SizedBox(
                  width: (constraints.maxWidth * 0.22).clamp(160, 280),
                  child: search,
                ),
              if (hasFilters)
                FilterPopoverAnchor(
                  child: _FiltersButton(
                    count: filter.activeTokenCount,
                    compact: narrow,
                    onTap: () => ref
                        .read(advFilterOpenProvider.notifier)
                        .update((v) => !v),
                  ),
                ),
              const Spacer(),
              if (layoutToggle) const BoardLayoutToggle(),
              const NewTicketButton(),
              const _RefreshButton(),
            ],
          );
        },
      ),
    );
  }
}

/// Below this toolbar width the filter tokens are left off.
const _kNarrowToolbar = 640.0;

/// Re-fetches the active board from its provider, bypassing the slice cache.
/// Shows a spinner and ignores taps while that fetch is in flight.
class _RefreshButton extends ConsumerWidget {
  const _RefreshButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppIconButton(
      icon: LucideIcons.rotateCw300,
      tooltip: AppL10n.of(context).refresh,
      isLoading: ref.watch(boardRefreshingProvider),
      onPressed: () => _refresh(context, ref),
    );
  }

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    final l = AppL10n.of(context);
    final res = await ref.read(refreshBoardProvider)();
    if (res case Err(:final failure)) {
      if (!context.mounted) return;
      showAppSnack(context, l.actionFailed(failure.message), isError: true);
    }
  }
}

class _SearchBox extends ConsumerStatefulWidget {
  const _SearchBox();

  @override
  ConsumerState<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends ConsumerState<_SearchBox> {
  late final TextEditingController controller = TextEditingController(
    text: ref.read(filterStateProvider).search,
  );

  /// A keystroke re-filters, re-groups and re-sorts every board; typing a
  /// word is one filter after the last key, not one per key.
  Timer? _debounce;
  static const _settle = Duration(milliseconds: 150);

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_settle, () {
      if (mounted) ref.read(filterStateProvider.notifier).setSearch(value);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the field in sync when search is cleared externally (Clear all).
    ref.listen(filterStateProvider.select((f) => f.search), (_, next) {
      if (next != controller.text) {
        // The outside change wins over a keystroke still waiting to apply.
        _debounce?.cancel();
        controller.text = next;
      }
    });
    return AppSearchField(
      controller: controller,
      hint: AppL10n.of(context).search,
      onChanged: _onChanged,
    );
  }
}

class _FiltersButton extends StatelessWidget {
  const _FiltersButton({
    required this.count,
    required this.onTap,
    this.compact = false,
  });
  final int count;
  final VoidCallback onTap;

  /// Leaves the label off (a narrow toolbar).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final active = count > 0;
    final color = active ? c.accent : c.textSecondary;
    final radius = BorderRadius.circular(context.radii.md);
    return HoverSurface(
      onTap: onTap,
      height: context.sizes.controlMd,
      padding: EdgeInsets.symmetric(horizontal: compact ? s.md : s.lg),
      color: active ? c.selectionFill : c.surface,
      borderRadius: radius,
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
