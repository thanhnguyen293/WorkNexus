import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/shell_pane/sidebar_primitives.dart';
import '../../domain/entities/zentao_project_group.dart';
import '../providers/zentao_board_providers.dart';
import 'zentao_project_tree_node.dart';

/// A program's folder in the ZenTao Tasks navigation tree, holding its
/// projects (see [ZenTaoProjectGroup]).
class ZentaoProjectSetNode extends ConsumerWidget {
  const ZentaoProjectSetNode({
    super.key,
    required this.account,
    required this.group,
    required this.openCountOf,
  });

  final Account account;
  final ZenTaoProjectGroup group;
  final int Function(String projectId) openCountOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final groupKey = '${account.id}:${group.id}';

    final isCollapsed = ref.watch(
      zentaoProjectSetsCollapsedProvider.select(
        (set) => set.contains(groupKey),
      ),
    );

    final totalCount = group.projects.fold<int>(
      0,
      (sum, p) => sum + openCountOf(p.id),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: s.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            mouseCursor: WidgetStateMouseCursor.clickable,
            onTap: () => ref
                .read(zentaoProjectSetsCollapsedProvider.notifier)
                .toggle(groupKey),
            borderRadius: BorderRadius.circular(context.radii.sm),
            child: Container(
              height: context.sizes.controlSm,
              padding: EdgeInsets.symmetric(horizontal: s.xs),
              child: Row(
                children: [
                  Icon(
                    isCollapsed
                        ? LucideIcons.chevronRight300
                        : LucideIcons.chevronDown300,
                    size: context.sizes.iconXs,
                    color: c.textTertiary,
                  ),
                  SizedBox(width: s.xs),
                  Icon(
                    LucideIcons.folderKanban300,
                    size: context.sizes.iconSm,
                    color: c.accent,
                  ),
                  SizedBox(width: s.xs),
                  Expanded(
                    child: Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.mono.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  if (totalCount > 0) ...[
                    SidebarCountBadge(totalCount),
                    SizedBox(width: s.xs),
                  ],
                ],
              ),
            ),
          ),
          if (!isCollapsed)
            SidebarTreeBranch(
              strong: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final p in group.projects)
                    ZentaoProjectTreeNode(
                      key: ValueKey('zentao_proj_${p.id}'),
                      account: account,
                      project: p,
                      openCount: openCountOf(p.id),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
