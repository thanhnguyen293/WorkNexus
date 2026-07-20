import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/util/relative_time.dart';
import '../../../../l10n/app_localizations.dart';
import 'detail_field_rows.dart';
import 'section_label.dart';

/// Dedicated metadata card for a GitLab issue / merge request. MR-only rows
/// (branches, merge status, reviewers) are omitted for issues and when empty.
class GitLabDetailSections extends ConsumerWidget {
  const GitLabDetailSections({
    super.key,
    required this.ticket,
    required this.entity,
  });

  final Ticket ticket;
  final GitLabItemEntity entity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final dateFormat = ref.watch(
      appSettingsProvider.select((s) => s.dateFormat),
    );
    final isMr = (ticket.externalType ?? '').toLowerCase() == 'mergerequest';

    final rows = <(String, String)>[
      (l.author, entity.author ?? ''),
      (l.assignee, entity.assignees.join(', ')),
      if (isMr) (l.reviewers, entity.reviewers.join(', ')),
      if (isMr) (l.sourceBranch, entity.sourceBranch ?? ''),
      if (isMr) (l.targetBranch, entity.targetBranch ?? ''),
      if (isMr) (l.mergeStatus, humanizeMergeState(entity.mergeStatus)),
      (l.updated, formatWhen(context, ticket.updatedAt, format: dateFormat)),
    ];
    return _MetaCard(title: l.details, rows: rows);
  }
}

/// Dedicated metadata card for a GitHub issue / pull request. PR-only rows
/// (branches, mergeable state, reviewers) are omitted for issues and when empty.
class GitHubDetailSections extends ConsumerWidget {
  const GitHubDetailSections({
    super.key,
    required this.ticket,
    required this.entity,
  });

  final Ticket ticket;
  final GitHubItemEntity entity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final dateFormat = ref.watch(
      appSettingsProvider.select((s) => s.dateFormat),
    );
    final isPr = (ticket.externalType ?? '').toLowerCase() == 'pullrequest';

    final rows = <(String, String)>[
      (l.author, entity.author ?? ''),
      (l.assignee, entity.assignees.join(', ')),
      if (isPr) (l.reviewers, entity.reviewers.join(', ')),
      if (isPr) (l.sourceBranch, entity.headBranch ?? ''),
      if (isPr) (l.targetBranch, entity.baseBranch ?? ''),
      if (isPr) (l.mergeStatus, humanizeMergeState(entity.mergeableState)),
      (l.updated, formatWhen(context, ticket.updatedAt, format: dateFormat)),
    ];
    return _MetaCard(title: l.details, rows: rows);
  }
}

/// GitLab/GitHub raw merge states are snake_case tokens (`need_rebase`,
/// `ci_still_running`, `behind`, `clean`, …); show them as readable words.
String humanizeMergeState(String? raw) {
  final words = (raw ?? '').replaceAll('_', ' ').trim();
  return words.isEmpty ? '' : '${words[0].toUpperCase()}${words.substring(1)}';
}

/// The bordered metadata card shared by both provider sidebars — a labeled
/// section over a hairline key/value table, with empty rows filtered out.
class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final filled = rows.where((r) => r.$2.trim().isNotEmpty).toList();
    if (filled.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.lg),
        border: Border.all(color: c.border),
      ),
      padding: EdgeInsets.fromLTRB(
        context.spacing.lg,
        context.spacing.lg,
        context.spacing.lg,
        context.spacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(title),
          SizedBox(height: context.spacing.xs),
          DetailFieldRows(rows: filled, labelWidth: 100, alignEnd: true),
        ],
      ),
    );
  }
}
