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
      (l.status, statusLabel(l, ticket.status)),
      (l.author, entity.author ?? ''),
      (l.assignee, entity.assignees.join(', ')),
      if (isMr) (l.reviewers, entity.reviewers.join(', ')),
      if (isMr) (l.sourceBranch, entity.sourceBranch ?? ''),
      if (isMr) (l.targetBranch, entity.targetBranch ?? ''),
      if (isMr) (l.mergeStatus, humanizeMergeState(entity.mergeStatus)),
      (l.updated, formatWhen(context, ticket.updatedAt, format: dateFormat)),
    ];
    return DetailMetaCard(
      title: l.details,
      rows: rows,
      valueWidgets: {l.status: TicketStatusPill(ticket: ticket)},
    );
  }
}
