import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/zentao_filter_providers.dart';

/// Collapsible module tree filter rail on the left of ZenTao views.
class ZenTaoModuleFilterSidebar extends ConsumerStatefulWidget {
  const ZenTaoModuleFilterSidebar({super.key, required this.totalCount});

  final int totalCount;

  @override
  ConsumerState<ZenTaoModuleFilterSidebar> createState() =>
      _ZenTaoModuleFilterSidebarState();
}

class _ZenTaoModuleFilterSidebarState
    extends ConsumerState<ZenTaoModuleFilterSidebar> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final modules = ref.watch(availableModulesProvider);
    final selectedModule = ref.watch(selectedModuleProvider);

    if (_collapsed) {
      return Container(
        width: 36,
        decoration: BoxDecoration(
          color: c.surfaceSubtle,
          border: Border(right: context.hairlineSide),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, size: 18),
              tooltip: 'Expand modules',
              onPressed: () => setState(() => _collapsed = false),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 175,
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        border: Border(right: context.hairlineSide),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with collapse button
          Container(
            height: 38,
            padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
            decoration: BoxDecoration(
              border: Border(bottom: context.hairlineSide),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_open_rounded,
                  size: 15,
                  color: c.textSecondary,
                ),
                SizedBox(width: context.spacing.xs),
                Text(
                  'Modules',
                  style: context.typography.monoXs.copyWith(
                    color: c.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => setState(() => _collapsed = true),
                  borderRadius: BorderRadius.circular(context.radii.xs),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 16,
                      color: c.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable module list
          Expanded(
            child: ListView(
              primary: false,
              padding: EdgeInsets.symmetric(
                vertical: context.spacing.xs,
                horizontal: context.spacing.xs,
              ),
              children: [
                _ModuleRow(
                  label: 'All Modules',
                  count: widget.totalCount,
                  isSelected: selectedModule == null,
                  onTap: () =>
                      ref.read(selectedModuleProvider.notifier).select(null),
                ),
                for (final mod in modules)
                  _ModuleRow(
                    label: mod.name,
                    count: mod.count,
                    isSelected: selectedModule == mod.name,
                    onTap: () => ref
                        .read(selectedModuleProvider.notifier)
                        .select(mod.name),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.radii.xs),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: isSelected ? c.selectionFill : Colors.transparent,
          borderRadius: BorderRadius.circular(context.radii.xs),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.bodySm.copyWith(
                  color: isSelected ? c.accent : c.textPrimary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: context.typography.monoXs.copyWith(
                color: isSelected ? c.accent : c.textTertiary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
