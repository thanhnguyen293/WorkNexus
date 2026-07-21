import 'package:flutter/material.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/relative_time.dart';
import '../../../../l10n/app_localizations.dart';
import 'detail_panel_header_actions.dart';

/// The two-pane GitHub PR header: title, panel-level actions, then a metadata
/// line — state pill, "{author} requested to merge", head → base branch pills,
/// and the opened-at time. Mirrors [GitLabMrHeader] with GitHub state labels.
class GitHubPrHeader extends StatelessWidget {
  const GitHubPrHeader({
    super.key,
    required this.ticket,
    required this.entity,
    required this.onClose,
    required this.onSync,
  });

  final Ticket ticket;
  final GitHubItemEntity entity;
  final VoidCallback onClose;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final head = entity.headBranch;
    final base = entity.baseBranch;
    return Container(
      padding: EdgeInsets.fromLTRB(
        context.spacing.xl3,
        context.spacing.xl2,
        context.spacing.lg,
        context.spacing.lg,
      ),
      decoration: BoxDecoration(border: Border(bottom: context.hairlineSide)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  ticket.title,
                  style: context.typography.display.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ),
              DetailPanelHeaderActions(
                ticket: ticket,
                onSync: onSync,
                onClosePanel: onClose,
              ),
            ],
          ),
          SizedBox(height: context.spacing.md),
          Wrap(
            spacing: context.spacing.sm,
            runSpacing: context.spacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatusPill(status: ticket.providerStatus),
              if ((entity.author ?? '').isNotEmpty)
                Text(
                  l.mrRequestedToMerge(entity.author!),
                  style: context.typography.secondary.copyWith(
                    color: c.textSecondary,
                  ),
                ),
              if (head != null && head.isNotEmpty) _BranchPill(head),
              if (head != null &&
                  head.isNotEmpty &&
                  base != null &&
                  base.isNotEmpty)
                Icon(
                  Icons.arrow_forward,
                  size: context.spacing.xl2,
                  color: c.textTertiary,
                ),
              if (base != null && base.isNotEmpty) _BranchPill(base),
              if (ticket.createdAt != null)
                Text(
                  formatWhen(context, ticket.createdAt),
                  style: context.typography.secondary.copyWith(
                    color: c.textTertiary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final normalized = status.toLowerCase();
    final (color, label) = switch (normalized) {
      'merged' => (c.info, l.githubColMerged),
      'closed' => (c.textTertiary, l.githubColClosed),
      'draft' => (c.warning, l.githubColDraft),
      _ => (c.success, l.githubColOpen),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.sm,
        vertical: context.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: c.mixT(color, 0.16),
        borderRadius: BorderRadius.circular(context.radii.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.merge_type, size: context.spacing.xl2, color: color),
          SizedBox(width: context.spacing.xs),
          Text(
            label,
            style: context.typography.captionStrong.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _BranchPill extends StatelessWidget {
  const _BranchPill(this.branch);

  final String branch;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.sm,
        vertical: context.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.sm),
      ),
      child: Text(
        branch,
        style: context.typography.captionStrong.copyWith(color: c.accent),
      ),
    );
  }
}
