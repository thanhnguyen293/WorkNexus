import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/util/labels.dart';
import '../../../../core/util/relative_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/detail/presentation/widgets/provider_detail_sections.dart';
import '../../../../shared/detail/presentation/widgets/ticket_status_pill.dart';

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
      (l.status, statusLabel(l, ticket.status)),
      (l.author, entity.author ?? ''),
      (l.assignee, entity.assignees.join(', ')),
      if (isPr) (l.reviewers, entity.reviewers.join(', ')),
      if (isPr) (l.sourceBranch, entity.headBranch ?? ''),
      if (isPr) (l.targetBranch, entity.baseBranch ?? ''),
      if (isPr) (l.mergeStatus, humanizeMergeState(entity.mergeableState)),
      (l.updated, formatWhen(context, ticket.updatedAt, format: dateFormat)),
    ];
    return DetailMetaCard(
      title: l.details,
      rows: rows,
      valueWidgets: {l.status: TicketStatusPill(ticket: ticket)},
    );
  }
}
