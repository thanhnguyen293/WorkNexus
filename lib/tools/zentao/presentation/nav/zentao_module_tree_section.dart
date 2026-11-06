import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
import '../providers/zentao_module_tree_provider.dart';

/// The board's module tree in its side panel: "All modules", then the
/// product's (bugs) or execution's (tasks) modules; a pick shows only that
/// module's tickets.
class ZenTaoModuleTreeSection extends ConsumerWidget {
  const ZenTaoModuleTreeSection({super.key, required this.bugs});

  /// The bug board, else the task board.
  final bool bugs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final picked = ref.watch(filterStateProvider.select((f) => f.modules));
    final filters = ref.read(filterStateProvider.notifier);
    final tree = ref.watch(zentaoModuleTreeProvider(bugs));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScopeGroupHeader(title: l.zentaoModulesGroup),
        switch (tree) {
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
        },
      ],
    );
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

/// The side panel's foot: hide or show the modules with nothing in them.
class ZenTaoHideEmptyModulesToggle extends ConsumerWidget {
  const ZenTaoHideEmptyModulesToggle({super.key});

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
