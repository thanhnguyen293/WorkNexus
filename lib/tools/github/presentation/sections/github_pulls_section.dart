import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/tools/tool_module.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/board/presentation/widgets/board_toolbar.dart';
import '../../domain/value_objects/github_item_kind.dart';
import '../providers/github_board_providers.dart';
import '../util/watch_github_items.dart';
import '../widgets/github_board_refresh_button.dart';
import '../widgets/github_board_view.dart';
import '../widgets/github_pr_row.dart';

/// The L5 Viewport section for GitHub Pull Requests.
/// Supports state tabs (Open / Merged / Closed) and Board mode, with quick filter chips.
class GithubPullsSection extends ConsumerWidget {
  const GithubPullsSection({
    super.key,
    required this.account,
    required this.location,
  });

  final Account account;
  final ToolLocation location;

  static List<ToolViewMode> get modes => [
    ToolViewMode(
      id: const ViewModeId('open'),
      label: (l) => l.viewOpen,
      icon: LucideIcons.gitPullRequest300,
    ),
    ToolViewMode(
      id: const ViewModeId('merged'),
      label: (l) => l.viewMerged,
      icon: LucideIcons.gitMerge300,
    ),
    ToolViewMode(
      id: const ViewModeId('closed'),
      label: (l) => l.viewClosed,
      icon: LucideIcons.circleX300,
    ),
    ToolViewMode(
      id: const ViewModeId('board'),
      label: (l) => l.viewBoard,
      icon: LucideIcons.kanban300,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchGitHubItems(context, ref, GitHubItemKind.pullRequest);
    final l = AppL10n.of(context);
    final c = context.colors;
    final s = context.spacing;
    final viewMode =
        location.viewModes[location.section] ?? const ViewModeId('open');

    final isReviewRequested = location.quickScope == QuickScope.reviewRequested;

    final allTickets =
        ref.watch(ticketsProvider).asData?.value ?? const <Ticket>[];

    // Filter tickets to GitHub PRs for this account
    final accountPrs = allTickets.where((t) {
      if (t.accountId != account.id || t.providerType != ProviderType.github) {
        return false;
      }
      final isPr = (t.externalType ?? '').toLowerCase() == 'pullrequest';
      if (!isPr) return false;

      // Scoping: by repository
      if (location.scopeId != null) {
        final repo = t.providerEntity is GitHubItemEntity
            ? (t.providerEntity as GitHubItemEntity).repo
            : t.projectId;
        if (repo != location.scopeId) return false;
      }

      // QuickScope: Review requested
      if (isReviewRequested) {
        final entity = t.providerEntity as GitHubItemEntity?;
        // Logins, as the account knows its user; items stored before they
        // were kept only have the reviewers' display names.
        final logins = entity?.reviewerLogins ?? const <String>[];
        final reviewers = logins.isNotEmpty
            ? logins
            : entity?.reviewers ?? const <String>[];
        if (!reviewers.any(
          (r) => r.toLowerCase() == account.handle.toLowerCase(),
        )) {
          return false;
        }
      }

      return true;
    }).toList();

    final Widget body;
    if (viewMode.value == 'board') {
      body = const GitHubBoardView(kind: GitHubItemKind.pullRequest);
    } else {
      final List<Ticket> filteredByState = switch (viewMode.value) {
        'merged' =>
          accountPrs
              .where(
                (t) => (t.providerEntity as GitHubItemEntity?)?.merged == true,
              )
              .toList(),
        'closed' =>
          accountPrs
              .where(
                (t) =>
                    t.status == UnifiedStatus.done &&
                    (t.providerEntity as GitHubItemEntity?)?.merged != true,
              )
              .toList(),
        'open' || _ =>
          accountPrs
              .where(
                (t) =>
                    t.status != UnifiedStatus.done &&
                    (t.providerEntity as GitHubItemEntity?)?.merged != true,
              )
              .toList(),
      };

      if (filteredByState.isEmpty) {
        body = Center(
          child: Text(
            'No pull requests in this view',
            style: context.typography.caption.copyWith(color: c.textSecondary),
          ),
        );
      } else {
        body = ListView.separated(
          padding: EdgeInsets.all(s.md),
          itemCount: filteredByState.length,
          separatorBuilder: (_, _) => SizedBox(height: s.xs),
          itemBuilder: (context, i) => GitHubPrRow(ticket: filteredByState[i]),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BoardToolbar(
          filters: [
            AppSegmentedTab(
              label: l.viewAll,
              active: !isReviewRequested,
              onTap: () => ref
                  .read(appNavProvider.notifier)
                  .setQuickScope(QuickScope.all),
            ),
            AppSegmentedTab(
              label: l.reviewRequested,
              active: isReviewRequested,
              onTap: () => ref
                  .read(appNavProvider.notifier)
                  .setQuickScope(QuickScope.reviewRequested),
            ),
          ],
          refresh: const GitHubBoardRefreshButton(),
          modes: modes,
          viewMode: viewMode,
          onViewMode: (m) {
            if (m.value == 'board') {
              ref
                  .read(githubKindProvider.notifier)
                  .set(GitHubItemKind.pullRequest);
            }
            ref.read(appNavProvider.notifier).setViewMode(m);
          },
        ),
        Expanded(child: body),
      ],
    );
  }
}
