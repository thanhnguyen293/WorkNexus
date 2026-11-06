import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../../../../shared/shell_pane/scope_rows.dart';
import '../../../../shared/shell_pane/sidebar_tree_rows.dart';
import '../../domain/usecases/build_zentao_module_tree.dart';
import '../providers/zentao_board_providers.dart';
import '../providers/zentao_module_tree_provider.dart';
import '../util/select_bug_board_product.dart';

/// The Bugs side panel: the open product and the pinned ones (any other
/// product is a pick away in the header's product switcher), then the open
/// product's module tree, which narrows the board like ZenTao's own.
class ZentaoBugModulePane extends ConsumerWidget {
  const ZentaoBugModulePane({
    super.key,
    required this.account,
    required this.location,
  });

  final Account account;
  final ToolLocation location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final products =
        ref.watch(zentaoProductsProvider(account.id)).asData?.value ?? const [];
    final pinned = ref.watch(
      appSettingsProvider.select((s) => s.pinnedProjects),
    );
    String keyOf(String productId) => '${account.id}:$productId';
    // The open product first, then the pinned ones.
    final rows = [
      ...products.where((p) => p.id == location.scopeId),
      ...products.where(
        (p) => p.id != location.scopeId && pinned.contains(keyOf(p.id)),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(s.sm, s.xs, s.sm, s.lg),
            children: [
              ScopeGroupHeader(title: l.zentaoProductsGroup),
              for (final p in rows)
                ScopeRow(
                  name: p.name,
                  icon: LucideIcons.package300,
                  selected: p.id == location.scopeId,
                  isPinned: pinned.contains(keyOf(p.id)),
                  onPinToggle: () => ref
                      .read(appSettingsProvider.notifier)
                      .togglePinnedProject(keyOf(p.id)),
                  onTap: () => selectBugBoardProduct(ref, p),
                ),
              SizedBox(height: s.sm),
              ScopeGroupHeader(title: l.zentaoModulesGroup),
              const _ModuleRows(),
            ],
          ),
        ),
        const _HideEmptyToggle(),
      ],
    );
  }
}

/// "All modules", then the tree; a pick shows only that module's bugs.
class _ModuleRows extends ConsumerWidget {
  const _ModuleRows();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final picked = ref.watch(filterStateProvider.select((f) => f.modules));
    final filters = ref.read(filterStateProvider.notifier);
    final tree = ref.watch(zentaoModuleTreeProvider);
    return switch (tree) {
      AsyncData(:final value) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScopeRow(
            name: l.zentaoAllModules,
            icon: LucideIcons.layers300,
            count: value.total,
            selected: picked.isEmpty,
            onTap: () => filters.selectModule(null),
          ),
          for (final node in value.nodes)
            _ModuleRow(
              node: node,
              // A pick of several (from the Filters popover) marks each.
              selected: picked.contains(node.id),
              onTap: () => filters.selectModule(node.id),
            ),
          if (value.nodes.isEmpty) _Note(l.zentaoNoModules),
        ],
      ),
      AsyncError() => _Note(l.zentaoModulesUnavailable),
      _ => SidebarStatusRow(label: l.zentaoModulesGroup, loading: true),
    };
  }
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({
    required this.node,
    required this.selected,
    required this.onTap,
  });

  final ZenTaoModuleNode node;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final row = ScopeRow(
      name: node.name,
      icon: node.depth == 0
          ? LucideIcons.folder300
          : LucideIcons.cornerDownRight300,
      count: node.count,
      selected: selected,
      onTap: onTap,
    );
    final indented = node.depth == 0
        ? row
        : Padding(
            padding: EdgeInsets.only(left: context.spacing.lg * node.depth),
            child: row,
          );
    // Empty modules read quieter, as ZenTao's own tree greys them.
    return node.count == 0 && !selected
        ? Opacity(opacity: 0.6, child: indented)
        : indented;
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(context.spacing.sm),
    child: Text(
      text,
      style: context.typography.captionSm.copyWith(
        color: context.colors.textTertiary,
      ),
    ),
  );
}

class _HideEmptyToggle extends ConsumerWidget {
  const _HideEmptyToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final hidden = ref.watch(zentaoHideEmptyModulesProvider);
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(top: context.hairlineSide)),
      child: HoverSurface(
        onTap: () => ref.read(zentaoHideEmptyModulesProvider.notifier).toggle(),
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.lg,
          vertical: context.spacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              hidden ? LucideIcons.eye300 : LucideIcons.eyeOff300,
              size: context.spacing.xl,
              color: c.textTertiary,
            ),
            SizedBox(width: context.spacing.sm),
            Text(
              hidden ? l.zentaoShowEmptyModules : l.zentaoHideEmptyModules,
              style: context.typography.captionSm.copyWith(
                color: c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
