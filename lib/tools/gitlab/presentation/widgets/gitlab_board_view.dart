import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_count_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/board/presentation/widgets/board_column_frame.dart';
import '../../../../shared/board/presentation/widgets/board_horizontal_scroll.dart';
import '../../domain/usecases/build_gitlab_issue_board.dart';
import '../../domain/usecases/build_gitlab_mr_board.dart';
import '../../domain/value_objects/gitlab_issue_column.dart';
import '../../domain/value_objects/gitlab_item_kind.dart';
import '../../domain/value_objects/gitlab_mr_column.dart';
import '../providers/gitlab_board_providers.dart';
import 'gitlab_ticket_card.dart';

/// The dedicated GitLab board: horizontally-scrolling lifecycle columns for the
/// selected project, switching between merge-request and issue columns with the
/// active [gitlabKindProvider]. Read-only (drag → state changes is Phase 3).
class GitLabBoardView extends ConsumerWidget {
  const GitLabBoardView({super.key, required this.kind});

  /// The section's kind. Not [gitlabKindProvider]: that is global and keeps
  /// the last Board tab picked, which may be the other section's.
  final GitLabItemKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columns = kind == GitLabItemKind.mergeRequest
        ? _mrColumns(context, ref.watch(gitlabMrBoardProvider))
        : _issueColumns(context, ref.watch(gitlabIssueBoardProvider));
    return BoardHorizontalScroll(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final col in columns) ...[
            _GitLabColumn(data: col),
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
    return BoardColumnFrame(
      dot: BoardColumnDot(data.color),
      label: data.label,
      badge: AppCountBadge(data.tickets.length),
      itemCount: data.tickets.length,
      itemBuilder: (context, i) => GitLabTicketCard(data.tickets[i]),
    );
  }
}
