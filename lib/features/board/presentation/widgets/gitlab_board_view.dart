import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/build_gitlab_issue_board.dart';
import '../../domain/usecases/build_gitlab_mr_board.dart';
import '../../domain/value_objects/gitlab_issue_column.dart';
import '../../domain/value_objects/gitlab_item_kind.dart';
import '../../domain/value_objects/gitlab_mr_column.dart';
import '../board_providers.dart';
import 'ticket_card.dart';

/// The dedicated GitLab board: horizontally-scrolling lifecycle columns for the
/// selected project, switching between merge-request and issue columns with the
/// active [gitlabKindProvider]. Read-only (drag → state changes is Phase 3).
class GitLabBoardView extends ConsumerWidget {
  const GitLabBoardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columns = ref.watch(gitlabKindProvider) == GitLabItemKind.mergeRequest
        ? _mrColumns(context, ref.watch(gitlabMrBoardProvider))
        : _issueColumns(context, ref.watch(gitlabIssueBoardProvider));
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.all(context.spacing.xl2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final col in columns) ...[
              _GitLabColumn(data: col),
              SizedBox(width: context.spacing.xl),
            ],
          ],
        ),
      ),
    );
  }
}

class _ColumnData {
  const _ColumnData(this.label, this.color, this.tickets);

  final String label;
  final Color color;
  final List<Ticket> tickets;
}

List<_ColumnData> _mrColumns(BuildContext context, GitLabMrBoardModel board) {
  final c = context.colors;
  final l = AppL10n.of(context);
  return [
    _ColumnData(
      l.gitlabColDraft,
      c.textTertiary,
      board.column(GitLabMrColumn.draft).tickets,
    ),
    _ColumnData(
      l.colReview,
      c.accent,
      board.column(GitLabMrColumn.review).tickets,
    ),
    _ColumnData(
      l.gitlabColMerged,
      c.success,
      board.column(GitLabMrColumn.merged).tickets,
    ),
    _ColumnData(
      l.gitlabColClosed,
      c.textSecondary,
      board.column(GitLabMrColumn.closed).tickets,
    ),
  ];
}

List<_ColumnData> _issueColumns(
  BuildContext context,
  GitLabIssueBoardModel board,
) {
  final c = context.colors;
  final l = AppL10n.of(context);
  return [
    _ColumnData(
      l.gitlabColOpen,
      c.accent,
      board.column(GitLabIssueColumn.open).tickets,
    ),
    _ColumnData(
      l.colInprogress,
      c.warning,
      board.column(GitLabIssueColumn.inProgress).tickets,
    ),
    _ColumnData(
      l.gitlabColClosed,
      c.textSecondary,
      board.column(GitLabIssueColumn.closed).tickets,
    ),
  ];
}

class _GitLabColumn extends StatelessWidget {
  const _GitLabColumn({required this.data});

  final _ColumnData data;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 272,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(context.radii.lg),
        border: context.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.spacing.xl,
              context.spacing.xl,
              context.spacing.xl,
              context.spacing.md,
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: data.color,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: context.spacing.md),
                Expanded(
                  child: Text(
                    data.label,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.bodySmStrong.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                ),
                SizedBox(width: context.spacing.md),
                _CountBadge(data.tickets.length),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                context.spacing.sm,
                context.spacing.xxs,
                context.spacing.sm,
                context.spacing.md,
              ),
              itemCount: data.tickets.length,
              itemBuilder: (context, i) => TicketCard(data.tickets[i]),
              separatorBuilder: (_, _) => SizedBox(height: context.spacing.md),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.sm,
        vertical: context.spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.xl),
        border: context.cardBorder,
      ),
      child: Text(
        '$count',
        style: context.typography.monoSm.copyWith(color: c.textTertiary),
      ),
    );
  }
}
