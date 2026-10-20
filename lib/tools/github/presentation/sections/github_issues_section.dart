import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/tools/tool_module.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../core/widgets/view_mode_tab_bar.dart';
import '../../domain/value_objects/github_item_kind.dart';
import '../providers/github_board_providers.dart';
import '../util/watch_github_items.dart';
import '../widgets/github_board_refresh_button.dart';
import '../widgets/github_board_view.dart';

/// The L5 Viewport section for GitHub Issues.
/// Supports List and Board view modes.
class GithubIssuesSection extends ConsumerWidget {
  const GithubIssuesSection({
    super.key,
    required this.account,
    required this.location,
  });

  final Account account;
  final ToolLocation location;

  static List<ToolViewMode> get modes => [
    ToolViewMode(
      id: const ViewModeId('list'),
      label: (l) => l.viewList,
      icon: LucideIcons.list300,
    ),
    ToolViewMode(
      id: const ViewModeId('board'),
      label: (l) => l.viewBoard,
      icon: LucideIcons.kanban300,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchGitHubItems(context, ref, GitHubItemKind.issue);
    final c = context.colors;
    final s = context.spacing;
    final viewMode =
        location.viewModes[location.section] ?? const ViewModeId('list');

    final allTickets =
        ref.watch(ticketsProvider).asData?.value ?? const <Ticket>[];

    final issues = allTickets.where((t) {
      if (t.accountId != account.id || t.providerType != ProviderType.github) {
        return false;
      }
      final isPr = (t.externalType ?? '').toLowerCase() == 'pullrequest';
      if (isPr) return false;

      // Scoping: by repository
      if (location.scopeId != null) {
        final repo = t.providerEntity is GitHubItemEntity
            ? (t.providerEntity as GitHubItemEntity).repo
            : t.projectId;
        if (repo != location.scopeId) return false;
      }

      return true;
    }).toList();

    final Widget body;
    if (viewMode.value == 'board') {
      body = const GitHubBoardView(kind: GitHubItemKind.issue);
    } else {
      if (issues.isEmpty) {
        body = Center(
          child: Text(
            'No issues in this view',
            style: context.typography.caption.copyWith(color: c.textSecondary),
          ),
        );
      } else {
        body = ListView.separated(
          padding: EdgeInsets.all(s.md),
          itemCount: issues.length,
          separatorBuilder: (_, _) => SizedBox(height: s.xs),
          itemBuilder: (context, i) => _IssueRow(ticket: issues[i]),
        );
      }
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
              const Spacer(),
              ViewModeTabBar(
                modes: modes,
                selectedModeId: viewMode,
                onModeSelected: (m) {
                  if (m.value == 'board') {
                    ref
                        .read(githubKindProvider.notifier)
                        .set(GitHubItemKind.issue);
                  }
                  ref.read(appNavProvider.notifier).setViewMode(m);
                },
              ),
              SizedBox(width: s.sm),
              const GitHubBoardRefreshButton(),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}

class _IssueRow extends ConsumerWidget {
  const _IssueRow({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final openId = ref.watch(openTicketIdProvider);
    final isSelected = openId == ticket.id;

    final repo = ticket.providerEntity is GitHubItemEntity
        ? (ticket.providerEntity as GitHubItemEntity).repo ?? ticket.projectId
        : ticket.projectId;
    final subtitle = '#${ticket.externalKey} · $repo';

    return HoverSurface(
      onTap: () => ref.read(appNavProvider.notifier).openTicket(ticket.id),
      selected: isSelected,
      borderRadius: BorderRadius.circular(context.radii.sm),
      padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.sm),
      child: Row(
        children: [
          Icon(LucideIcons.circleDot300, size: 18, color: c.accent),
          SizedBox(width: s.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ticket.title,
                  style: context.typography.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isSelected ? c.accent : c.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: s.xxs),
                Text(
                  subtitle,
                  style: context.typography.caption.copyWith(
                    color: c.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
