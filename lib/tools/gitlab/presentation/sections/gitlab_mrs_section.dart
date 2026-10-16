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
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/tools/tool_module.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../core/widgets/view_mode_tab_bar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/board/domain/usecases/is_assigned_to_me.dart';
import '../../domain/value_objects/gitlab_item_kind.dart';
import '../providers/gitlab_board_providers.dart';
import '../providers/gitlab_scope.dart';
import '../util/watch_gitlab_items.dart';
import '../widgets/gitlab_board_view.dart';
import '../widgets/gitlab_mr_table.dart';

enum GitLabMrChip { allOpen, draft, inReview, assignedToMe }

class GitLabMrChipNotifier extends Notifier<GitLabMrChip> {
  @override
  GitLabMrChip build() => GitLabMrChip.allOpen;

  void set(GitLabMrChip chip) => state = chip;
}

final gitlabMrChipFilterProvider =
    NotifierProvider.autoDispose<GitLabMrChipNotifier, GitLabMrChip>(
      GitLabMrChipNotifier.new,
    );

/// The L5 Viewport section for GitLab Merge Requests (specs S5.5).
/// Supports state tabs (Open / Merged / Closed) and Board mode,
/// with chips: All open, Draft, In review, Assigned to me.
class GitlabMrsSection extends ConsumerWidget {
  const GitlabMrsSection({
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
    watchGitLabItems(context, ref, GitLabItemKind.mergeRequest);
    final l = AppL10n.of(context);
    final c = context.colors;
    final s = context.spacing;
    final viewMode =
        location.viewModes[location.section] ?? const ViewModeId('open');

    final activeChip = ref.watch(gitlabMrChipFilterProvider);
    final allTickets =
        ref.watch(ticketsProvider).asData?.value ?? const <Ticket>[];

    // Filter tickets to GitLab MRs for this account
    final accountMrs = allTickets.where((t) {
      if (t.accountId != account.id || t.providerType != ProviderType.gitlab) {
        return false;
      }
      final isMr = (t.externalType ?? '').toLowerCase() == 'mergerequest';
      if (!isMr) return false;

      // Scoping: by project
      if (location.scopeId case final scopeId?) {
        if (!gitlabTicketInProject(t, scopeId)) return false;
      }

      // QuickScope: Assigned to me
      // (matched on assignee logins: names are display names)
      if (location.quickScope == QuickScope.assignedToMe &&
          !const IsAssignedToMe()(t, account)) {
        return false;
      }

      return true;
    }).toList();

    final Widget body;
    if (viewMode.value == 'board') {
      body = const GitLabBoardView(kind: GitLabItemKind.mergeRequest);
    } else {
      // Filter by state view mode
      final List<Ticket> stateFiltered = switch (viewMode.value) {
        'merged' =>
          accountMrs
              .where((t) => t.providerStatus.toLowerCase() == 'merged')
              .toList(),
        'closed' =>
          accountMrs
              .where(
                (t) =>
                    (t.status == UnifiedStatus.done ||
                        t.providerStatus.toLowerCase() == 'closed') &&
                    t.providerStatus.toLowerCase() != 'merged',
              )
              .toList(),
        'open' || _ =>
          accountMrs
              .where(
                (t) =>
                    t.status != UnifiedStatus.done &&
                    t.providerStatus.toLowerCase() != 'merged' &&
                    t.providerStatus.toLowerCase() != 'closed',
              )
              .toList(),
      };

      // Apply chip filter
      final chipFiltered = stateFiltered.where((t) {
        final entity = t.providerEntity as GitLabItemEntity?;
        return switch (activeChip) {
          GitLabMrChip.allOpen => true,
          GitLabMrChip.draft => entity?.draft == true,
          GitLabMrChip.inReview => entity?.reviewers.isNotEmpty == true,
          GitLabMrChip.assignedToMe => const IsAssignedToMe()(t, account),
        };
      }).toList();

      body = GitLabMrTable(tickets: chipFiltered);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Viewport toolbar
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(bottom: context.hairlineSide),
          ),
          padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.xs),
          child: Row(
            children: [
              _FilterChip(
                label: l.allOpen,
                selected: activeChip == GitLabMrChip.allOpen,
                onTap: () => ref
                    .read(gitlabMrChipFilterProvider.notifier)
                    .set(GitLabMrChip.allOpen),
              ),
              SizedBox(width: s.xs),
              _FilterChip(
                label: l.draft,
                selected: activeChip == GitLabMrChip.draft,
                onTap: () => ref
                    .read(gitlabMrChipFilterProvider.notifier)
                    .set(GitLabMrChip.draft),
              ),
              SizedBox(width: s.xs),
              _FilterChip(
                label: l.inReview,
                selected: activeChip == GitLabMrChip.inReview,
                onTap: () => ref
                    .read(gitlabMrChipFilterProvider.notifier)
                    .set(GitLabMrChip.inReview),
              ),
              SizedBox(width: s.xs),
              _FilterChip(
                label: l.assignedToMe,
                selected: activeChip == GitLabMrChip.assignedToMe,
                onTap: () => ref
                    .read(gitlabMrChipFilterProvider.notifier)
                    .set(GitLabMrChip.assignedToMe),
              ),
              const Spacer(),
              ViewModeTabBar(
                modes: modes,
                selectedModeId: viewMode,
                onModeSelected: (m) {
                  if (m.value == 'board') {
                    ref
                        .read(gitlabKindProvider.notifier)
                        .set(GitLabItemKind.mergeRequest);
                  }
                  ref.read(appNavProvider.notifier).setViewMode(m);
                },
              ),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;

    return HoverSurface(
      onTap: onTap,
      selected: selected,
      borderRadius: BorderRadius.circular(context.radii.sm),
      color: selected ? c.selectionFill : c.surfaceSubtle,
      padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xxs),
      child: Text(
        label,
        style: context.typography.caption.copyWith(
          color: selected ? c.accent : c.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }
}
