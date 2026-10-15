import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_count_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/board/presentation/widgets/board_column_frame.dart';
import '../../../../shared/board/presentation/widgets/board_horizontal_scroll.dart';
import '../../../../shared/board/presentation/widgets/ticket_card.dart';
import '../../domain/usecases/build_github_issue_board.dart';
import '../../domain/usecases/build_github_pr_board.dart';
import '../../domain/value_objects/github_issue_column.dart';
import '../../domain/value_objects/github_item_kind.dart';
import '../../domain/value_objects/github_pr_column.dart';
import '../providers/github_board_providers.dart';

/// The dedicated GitHub board: horizontally-scrolling lifecycle columns for the
/// selected repo, switching between pull-request and issue columns with the
/// active [githubKindProvider]. Read-only (state changes go through the detail
/// panel actions).
class GitHubBoardView extends ConsumerWidget {
  const GitHubBoardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columns = ref.watch(githubKindProvider) == GitHubItemKind.pullRequest
        ? _prColumns(context, ref.watch(githubPrBoardProvider))
        : _issueColumns(context, ref.watch(githubIssueBoardProvider));
    return BoardHorizontalScroll(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final col in columns) ...[
            _GitHubColumn(data: col),
            SizedBox(width: context.spacing.xl),
          ],
        ],
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

List<_ColumnData> _prColumns(BuildContext context, GitHubPrBoardModel board) {
  final c = context.colors;
  final l = AppL10n.of(context);
  return [
    _ColumnData(
      l.githubColDraft,
      c.textTertiary,
      board.column(GitHubPrColumn.draft).tickets,
    ),
    _ColumnData(
      l.colReview,
      c.accent,
      board.column(GitHubPrColumn.review).tickets,
    ),
    _ColumnData(
      l.githubColMerged,
      c.success,
      board.column(GitHubPrColumn.merged).tickets,
    ),
    _ColumnData(
      l.githubColClosed,
      c.textSecondary,
      board.column(GitHubPrColumn.closed).tickets,
    ),
  ];
}

List<_ColumnData> _issueColumns(
  BuildContext context,
  GitHubIssueBoardModel board,
) {
  final c = context.colors;
  final l = AppL10n.of(context);
  return [
    _ColumnData(
      l.githubColOpen,
      c.accent,
      board.column(GitHubIssueColumn.open).tickets,
    ),
    _ColumnData(
      l.colInprogress,
      c.warning,
      board.column(GitHubIssueColumn.inProgress).tickets,
    ),
    _ColumnData(
      l.githubColClosed,
      c.textSecondary,
      board.column(GitHubIssueColumn.closed).tickets,
    ),
  ];
}

class _GitHubColumn extends StatelessWidget {
  const _GitHubColumn({required this.data});

  final _ColumnData data;

  @override
  Widget build(BuildContext context) {
    return BoardColumnFrame(
      dot: BoardColumnDot(data.color),
      label: data.label,
      badge: AppCountBadge(data.tickets.length),
      itemCount: data.tickets.length,
      itemBuilder: (context, i) => TicketCard(data.tickets[i]),
    );
  }
}
