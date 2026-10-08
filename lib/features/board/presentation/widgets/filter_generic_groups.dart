import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/value_objects/priority.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/util/labels.dart';
import '../../../../l10n/app_localizations.dart';
import '../board_providers.dart';
import 'filter_chip.dart';
import 'filter_option_group.dart';

/// The cross-provider groups used by the generic board/list views.
class GenericFilterGroups extends ConsumerWidget {
  const GenericFilterGroups({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final f = ref.watch(filterStateProvider);
    final ctrl = ref.read(filterStateProvider.notifier);
    final lookups = ref.watch(lookupsProvider);
    // Only offer the providers/accounts/projects actually present in the current
    // board's scope — so a GitLab/GitHub or "my MRs" board doesn't list every
    // workspace project (or unconnected providers like Jira).
    final scope = ref.watch(genericFilterScopeProvider);
    // On the account-wide "my MRs/PRs" board the only useful axis is project
    // (every item is yours, one provider/account), so status/priority are hidden.
    final mineBoard =
        ref.watch(
          selectedGitLabProjectProvider.select((s) => s?.mine ?? false),
        ) ||
        ref.watch(selectedGitHubRepoProvider.select((s) => s?.mine ?? false));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterGroup(
          label: l.provider,
          children: [
            for (final p in ProviderType.values)
              if (scope.providers.contains(p))
                FilterOptionChip(
                  label: p.displayName,
                  active: f.providers.contains(p),
                  onTap: () => ctrl.toggleProvider(p),
                ),
          ],
        ),
        // Accounts and projects are the long lists here (a workspace can hold
        // dozens), so both get a search box once they grow.
        SearchableFilterGroup(
          label: l.account,
          options: [
            for (final a in lookups.accounts.values)
              if (scope.accountIds.contains(a.id))
                FilterChipOption(
                  label: a.handle,
                  active: f.accountIds.contains(a.id),
                  dotColor: switch (lookups.workspaces[a.workspaceId]) {
                    final ws? => Color(ws.colorValue),
                    null => c.workspaceFallback,
                  },
                  onTap: () => ctrl.toggleAccount(a.id),
                ),
          ],
        ),
        SearchableFilterGroup(
          label: l.project,
          options: [
            for (final p in lookups.projects.values)
              if (scope.projectIds.contains(p.id))
                FilterChipOption(
                  label: p.name,
                  active: f.projectIds.contains(p.id),
                  onTap: () => ctrl.toggleProject(p.id),
                ),
          ],
        ),
        if (!mineBoard)
          FilterGroup(
            label: l.status,
            children: [
              for (final s in UnifiedStatus.columns)
                FilterOptionChip(
                  label: statusLabel(l, s),
                  active: f.statuses.contains(s),
                  dotColor: statusColor(c, s),
                  onTap: () => ctrl.toggleStatus(s),
                ),
            ],
          ),
        if (!mineBoard)
          FilterGroup(
            label: l.priority,
            children: [
              for (final p in Priority.values)
                FilterOptionChip(
                  label: priorityName(l, p),
                  active: f.priorities.contains(p),
                  dotColor: priorityColor(c, p),
                  onTap: () => ctrl.togglePriority(p),
                ),
            ],
          ),
      ],
    );
  }
}
