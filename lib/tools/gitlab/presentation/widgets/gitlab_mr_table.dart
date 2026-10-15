import 'package:flutter/material.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import 'gitlab_mr_table_row.dart';

/// Table view for GitLab Merge Requests (specs S5.5).
/// Columns: MR, Title, State, Updated.
class GitLabMrTable extends StatelessWidget {
  const GitLabMrTable({super.key, required this.tickets});

  final List<Ticket> tickets;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;

    if (tickets.isEmpty) {
      return Center(
        child: Text(
          'No merge requests in this view',
          style: context.typography.caption.copyWith(color: c.textSecondary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Table header
        Container(
          decoration: BoxDecoration(
            color: c.surfaceSubtle,
            border: Border(bottom: context.hairlineSide),
          ),
          padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.xs),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  'MR',
                  style: context.typography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                  ),
                ),
              ),
              SizedBox(width: s.sm),
              Expanded(
                child: Text(
                  'Title',
                  style: context.typography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                  ),
                ),
              ),
              SizedBox(width: s.md),
              SizedBox(
                width: 120,
                child: Text(
                  'State',
                  style: context.typography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                  ),
                ),
              ),
              SizedBox(width: s.sm),
              SizedBox(
                width: 110,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Updated',
                    style: context.typography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Table body
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.symmetric(vertical: s.xs),
            itemCount: tickets.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, thickness: 1, color: c.border),
            itemBuilder: (context, i) => GitLabMrTableRow(ticket: tickets[i]),
          ),
        ),
      ],
    );
  }
}
