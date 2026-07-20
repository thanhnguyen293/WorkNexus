import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../board_providers.dart';
import 'active_tokens.dart';

/// Whether the advanced-filter popover is open.
final advFilterOpenProvider = StateProvider<bool>((ref) => false);

/// The top toolbar: search, filters button (hidden when nothing to filter),
/// active tokens.
class ChromeBar extends ConsumerWidget {
  const ChromeBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final filter = ref.watch(filterStateProvider);
    final hasFilters = ref.watch(filterHasGroupsProvider);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: context.hairlineSide),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.xl2,
        vertical: context.spacing.md,
      ),
      child: Row(
        children: [
          const _SearchBox(),
          if (hasFilters) ...[
            SizedBox(width: context.spacing.lg),
            _FiltersButton(
              count: filter.activeTokenCount,
              onTap: () =>
                  ref.read(advFilterOpenProvider.notifier).update((v) => !v),
            ),
          ],
          SizedBox(width: context.spacing.lg),
          const Expanded(child: ActiveTokens()),
        ],
      ),
    );
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
          fillColor: c.surfaceSubtle,
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
          color: count > 0 ? c.selectionFill : c.surfaceSubtle,
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
