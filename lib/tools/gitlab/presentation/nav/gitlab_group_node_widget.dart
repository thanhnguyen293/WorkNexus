import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/shell_pane/sidebar_primitives.dart';
import '../../domain/entities/gitlab_project_tree.dart';
import '../providers/gitlab_board_providers.dart';
import 'gitlab_project_tree_node.dart';

/// A recursive group/subgroup row in the GitLab project tree.
class GitLabGroupNodeWidget extends ConsumerWidget {
  const GitLabGroupNodeWidget({
    super.key,
    required this.account,
    required this.node,
    required this.location,
    required this.openCountOf,
    this.isRoot = false,
  });

  final Account account;
  final GitLabGroupNode node;
  final ToolLocation location;
  final int Function(String projectId) openCountOf;
  final bool isRoot;

  int _aggregateCount(GitLabGroupNode n) {
    var count = 0;
    for (final p in n.projects) {
      count += openCountOf(p.id);
    }
    for (final sub in n.subgroups) {
      count += _aggregateCount(sub);
    }
    return count;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final groupKey = '${account.id}:${node.fullPath}';

    final isCollapsed = ref.watch(
      gitlabGroupsCollapsedProvider.select((set) => set.contains(groupKey)),
    );

    final totalCount = _aggregateCount(node);
    final pinned = ref.watch(
      appSettingsProvider.select((st) => st.pinnedProjects),
    );

    String keyOf(ProviderProject p) => '${p.accountId}:${p.id}';

    return Padding(
      padding: EdgeInsets.only(bottom: s.xxs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            mouseCursor: WidgetStateMouseCursor.clickable,
            onTap: () => ref
                .read(gitlabGroupsCollapsedProvider.notifier)
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
                    isRoot ? LucideIcons.folderGit2300 : LucideIcons.folder300,
                    size: context.sizes.iconSm,
                    color: isRoot ? c.accent : c.textSecondary,
                  ),
                  SizedBox(width: s.xs),
                  Expanded(
                    child: Text(
                      node.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.mono.copyWith(
                        fontWeight: isRoot ? FontWeight.w600 : FontWeight.w500,
                        color: c.textPrimary,
                        fontSize: isRoot ? 12 : 11.5,
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
              strong: isRoot,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final sub in node.subgroups)
                    GitLabGroupNodeWidget(
                      key: ValueKey('gitlab_group_${sub.fullPath}'),
                      account: account,
                      node: sub,
                      location: location,
                      openCountOf: openCountOf,
                    ),
                  for (final p in node.projects)
                    GitLabProjectTreeNode(
                      key: ValueKey('gitlab_proj_${p.id}'),
                      project: p,
                      openCount: openCountOf(p.id),
                      selected: location.scopeId == p.id,
                      isPinned: pinned.contains(keyOf(p)),
                      onPinToggle: () => ref
                          .read(appSettingsProvider.notifier)
                          .togglePinnedProject(keyOf(p)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
