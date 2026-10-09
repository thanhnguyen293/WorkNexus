import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../board_providers.dart';
import '../board_refresh.dart';
import 'active_tokens.dart';
import 'board_view_tabs.dart';
import 'new_ticket_button.dart';
import 'sidebar_primitives.dart';

/// Whether the advanced-filter popover is open.
final advFilterOpenProvider = StateProvider<bool>((ref) => false);

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
                _FiltersButton(
                  count: filter.activeTokenCount,
                  compact: narrow,
                  onTap: () => ref
                      .read(advFilterOpenProvider.notifier)
                      .update((v) => !v),
                ),
              if (!narrow) const Expanded(child: ActiveTokens()),
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
    final c = context.colors;
    final l = AppL10n.of(context);
    final busy = ref.watch(boardRefreshingProvider);
    return Tooltip(
      message: l.refresh,
      child: InkWell(
        onTap: busy ? null : () => _refresh(context, ref),
        borderRadius: BorderRadius.circular(context.radii.md),
        child: Container(
          width: kBoardToolbarControlHeight,
          height: kBoardToolbarControlHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(context.radii.md),
            border: context.cardBorder,
          ),
          child: busy
              ? const SidebarSyncIndicator()
              : Icon(
                  PhosphorIconsLight.arrowClockwise,
                  size: 16,
                  color: c.textSecondary,
                ),
        ),
      ),
    );
  }

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = AppL10n.of(context);
    final res = await ref.read(refreshBoardProvider)();
    if (res case Err(:final failure)) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.actionFailed(failure.message))),
      );
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

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    // Keep the field in sync when search is cleared externally (Clear all).
    ref.listen(filterStateProvider.select((f) => f.search), (_, next) {
      if (next != controller.text) controller.text = next;
    });
    return SizedBox(
      height: kBoardToolbarControlHeight,
      child: TextField(
        controller: controller,
        onChanged: (v) => ref.read(filterStateProvider.notifier).setSearch(v),
        style: context.typography.secondary.copyWith(color: c.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: c.surface,
          hintText: l.search,
          hintStyle: context.typography.secondary.copyWith(
            color: c.textTertiary,
          ),
          prefixIcon: Icon(
            PhosphorIconsLight.magnifyingGlass,
            size: 15,
            color: c.textTertiary,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 30,
            minHeight: 30,
          ),
          contentPadding: EdgeInsets.symmetric(
            vertical: context.spacing.sm,
            horizontal: context.spacing.xs,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(context.radii.md),
            borderSide: context.borders.showOutline
                ? BorderSide(color: c.border)
                : BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(context.radii.md),
            borderSide: context.borders.showOutline
                ? BorderSide(color: c.border)
                : BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(context.radii.md),
            borderSide: BorderSide(color: c.accent),
          ),
        ),
      ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: radius,
      child: Container(
        height: kBoardToolbarControlHeight,
        padding: EdgeInsets.symmetric(horizontal: compact ? s.md : s.lg),
        decoration: BoxDecoration(
          color: active ? c.selectionFill : c.surface,
          borderRadius: radius,
          border: context.cardBorder,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? PhosphorIconsFill.funnel : PhosphorIconsLight.funnel,
              size: s.xl3,
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
              Container(
                padding: EdgeInsets.symmetric(horizontal: s.sm),
                decoration: BoxDecoration(
                  color: c.accent,
                  borderRadius: BorderRadius.circular(context.radii.pill),
                ),
                child: Text(
                  '$count',
                  style: context.typography.monoXs.copyWith(
                    color: c.onAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
