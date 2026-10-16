import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/shell_pane/sidebar_primitives.dart';
import '../../../../shared/shell_pane/sidebar_tree_rows.dart';
import '../providers/zentao_board_providers.dart';
import '../widgets/zentao_execution_row.dart';

/// A project in the ZenTao Tasks navigation tree: a container of executions
/// — tapping it opens or closes them. ZenTao lists tasks per execution, so a
/// project is neither selected nor pinned; its count is information only.
class ZentaoProjectTreeNode extends ConsumerWidget {
  const ZentaoProjectTreeNode({
    super.key,
    required this.account,
    required this.project,
    required this.openCount,
  });

  final Account account;
  final ProviderProject project;
  final int openCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final key = '${account.id}:${project.id}';

    final expanded = ref.watch(
      zentaoExecutionProjectsExpandedProvider.select(
        (set) => set.contains(key),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          mouseCursor: WidgetStateMouseCursor.clickable,
          onTap: () => ref
              .read(zentaoExecutionProjectsExpandedProvider.notifier)
              .toggle(key),
          borderRadius: BorderRadius.circular(context.radii.sm),
          child: Container(
            height: context.sizes.controlSm,
            padding: EdgeInsets.symmetric(horizontal: s.xs),
            child: Row(
              children: [
                Icon(
                  expanded
                      ? LucideIcons.chevronDown300
                      : LucideIcons.chevronRight300,
                  size: context.sizes.iconXs,
                  color: c.textTertiary,
                ),
                SizedBox(width: s.xs),
                Icon(
                  LucideIcons.folder300,
                  size: context.sizes.iconSm,
                  color: c.textSecondary,
                ),
                SizedBox(width: s.xs),
                Expanded(
                  child: Text(
                    project.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.bodySm.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ),
                if (openCount > 0) ...[
                  SidebarCountBadge(openCount),
                  SizedBox(width: s.xs),
                ],
              ],
            ),
          ),
        ),
        if (expanded)
          SidebarTreeBranch(
            child: _ProjectExecutions(account: account, projectId: project.id),
          ),
      ],
    );
  }
}

class _ProjectExecutions extends ConsumerWidget {
  const _ProjectExecutions({required this.account, required this.projectId});

  final Account account;
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final executionsAsync = ref.watch(
      zentaoExecutionsProvider((accountId: account.id, projectId: projectId)),
    );
    final pinnedKeys = {
      for (final e in ref.watch(
        appSettingsProvider.select((s) => s.pinnedExecutions),
      ))
        e.key,
    };

    return executionsAsync.when(
      data: (executions) {
        if (executions.isEmpty) {
          return SidebarStatusRow(label: l.noExecutions);
        }
        // Pinned executions are lifted into Pinned, out of the tree.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final execution in executions)
              if (!pinnedKeys.contains('${account.id}:${execution.id}'))
                ZenTaoExecutionRow(
                  key: ValueKey('exec_${execution.id}'),
                  execution: execution,
                  pinned: false,
                ),
          ],
        );
      },
      loading: () =>
          SidebarStatusRow(label: l.loadingExecutions, loading: true),
      error: (_, _) => SidebarStatusRow(
        label: l.executionsUnavailable,
        isError: true,
        onRetry: () => ref.invalidate(
          zentaoExecutionsProvider((
            accountId: account.id,
            projectId: projectId,
          )),
        ),
      ),
    );
  }
}
