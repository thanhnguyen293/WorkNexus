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

/// The two-pane MR header: title, panel-level actions (refresh / link / edit /
/// close-panel), then a metadata line — status pill, "{author} requested to
/// merge", source → target branch pills, and the opened-at time.
class GitLabMrHeader extends StatelessWidget {
  const GitLabMrHeader({
    super.key,
    required this.ticket,
    required this.entity,
    required this.onClose,
    required this.onSync,
  });

  final Ticket ticket;
  final GitLabItemEntity entity;
  final VoidCallback onClose;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final source = entity.sourceBranch;
    final target = entity.targetBranch;
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
              if (source != null && source.isNotEmpty) _BranchPill(source),
              if (source != null &&
                  source.isNotEmpty &&
                  target != null &&
                  target.isNotEmpty)
                Icon(
                  Icons.arrow_forward,
                  size: context.spacing.xl2,
                  color: c.textTertiary,
                ),
              if (target != null && target.isNotEmpty) _BranchPill(target),
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

/// The MR state chip (Open / Draft / Merged / Closed), color-coded off the raw
/// provider status.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final normalized = status.toLowerCase();
    final (color, label) = switch (normalized) {
      'merged' => (c.info, l.gitlabColMerged),
      'closed' => (c.textTertiary, l.gitlabColClosed),
      'draft' => (c.warning, l.gitlabColDraft),
      _ => (c.success, l.gitlabColOpen),
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
          Icon(
            Icons.account_tree_outlined,
            size: context.spacing.xl2,
            color: color,
          ),
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

/// A monospace-ish pill for a git branch name.
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
