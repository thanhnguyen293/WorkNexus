import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../l10n/app_localizations.dart';
import '../board_providers.dart';
import 'sidebar_primitives.dart';

/// A single ZenTao project (product) row: a dot, the name and a pin toggle.
/// Tapping the row opens the product's bug board (defaulting to the current
/// user's tickets), which then fetches the default tab (browse type) from ZenTao.
class ZenTaoProjectRow extends ConsumerWidget {
  const ZenTaoProjectRow({
    super.key,
    required this.product,
    required this.tickets,
    required this.pinned,
    this.showKindTag = false,
  });

  final ProviderProduct product;
  final List<Ticket> tickets;
  final bool pinned;

  /// Whether to show the "Bug" kind tag (used in the combined Pinned area, where
  /// bugs and tasks sit side by side).
  final bool showKindTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final selected = ref.watch(selectedZenTaoProductProvider);
    final key = '${product.accountId}:${product.id}';
    final active =
        selected?.accountId == product.accountId &&
        selected?.productId == product.id;
    // While this product is the open board and its active tab is fetching.
    final loading = active && ref.watch(zentaoBugSliceProvider).isLoading;

    return Opacity(
      opacity: loading ? 0.48 : 1,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: loading ? null : () => _select(ref),
        borderRadius: BorderRadius.circular(context.radii.sm),
        child: Container(
          height: 27,
          padding: EdgeInsets.only(
            left: context.spacing.sm,
            right: context.spacing.xxs,
          ),
          decoration: BoxDecoration(
            color: active ? c.selectionFill : Colors.transparent,
            borderRadius: BorderRadius.circular(context.radii.sm),
          ),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: c.accent,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: context.spacing.sm),
              Expanded(
                child: Text(
                  product.name,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.mono.copyWith(
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: c.textPrimary,
                  ),
                ),
              ),
              if (showKindTag) ...[
                MiniTag(l.bugTag, c.accent),
                SizedBox(width: context.spacing.xs),
              ],
              if (loading) ...[
                const SidebarSyncIndicator(),
                SizedBox(width: context.spacing.xxs),
              ],
              SidebarPinButton(
                pinned: pinned,
                tooltip: pinned ? l.unpinProject : l.pinProject,
                onTap: () => ref
                    .read(appSettingsProvider.notifier)
                    .togglePinnedProject(key),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens this product's bug board and resets to the default tab. The board's
  /// `zentaoBugStreamsProvider` reacts to the selection and pages each column's
  /// view into the DB, which the board reads reactively.
  /// Leaves any open settings view and hands the filter to this board's memory —
  /// a first visit opens unfiltered.
  void _select(WidgetRef ref) {
    showBoardView(ref);
    ref.read(selectedGitLabProjectProvider.notifier).clear();
    ref.read(selectedGitHubRepoProvider.notifier).clear();
    ref.read(selectedZenTaoExecutionProvider.notifier).clear();
    ref.read(selectedZenTaoProductProvider.notifier).select(product);
    ref.read(zentaoBugTabProvider.notifier).reset();
    ref.read(viewModeProvider.notifier).set(ViewMode.zentaoBugs);
    // Read the board key only once the selection above is in place — it is
    // derived from it.
    ref
        .read(filterStateProvider.notifier)
        .openBoard(ref.read(boardKeyProvider));
  }
}
