import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

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
        // The board canvas color (not the sidebar's surface) so the toolbar
        // reads as part of the board and doesn't blend into the sidebar.
        color: c.background,
        border: Border(bottom: context.hairlineSide),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.xl2,
        vertical: context.spacing.md,
      ),
      child: Row(
        spacing: context.spacing.lg,
        children: [
          ?tabs,
          const _SearchBox(),
          if (hasFilters)
            _FiltersButton(
              count: filter.activeTokenCount,
              onTap: () =>
                  ref.read(advFilterOpenProvider.notifier).update((v) => !v),
            ),
          const Expanded(child: ActiveTokens()),
          const _RefreshButton(),
        ],
      ),
    );
  }
}

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
          width: 31,
          height: 31,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(context.radii.md),
            border: context.cardBorder,
          ),
          child: busy
              ? const SidebarSyncIndicator()
              : Icon(Icons.refresh, size: 16, color: c.textSecondary),
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
      width: 220,
      height: 31,
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
          prefixIcon: Icon(Icons.search, size: 15, color: c.textTertiary),
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
  const _FiltersButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 31,
        padding: EdgeInsets.symmetric(horizontal: context.spacing.lg),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: count > 0 ? c.selectionFill : c.surface,
          borderRadius: BorderRadius.circular(context.radii.md),
          border: context.cardBorder,
        ),
        child: Text(
          '⚑ ${l.filters}${count > 0 ? ' · $count' : ''}',
          style: context.typography.bodySm.copyWith(
            fontWeight: FontWeight.w500,
            color: count > 0 ? c.accent : c.textSecondary,
          ),
        ),
      ),
    );
  }
}
