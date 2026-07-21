import 'package:flutter/material.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import 'provider_detail_sections.dart';

/// The merge widget — shown only while the MR is open. Surfaces the real merge
/// state (blocked-needs-rebase vs. ready), an Approve action, and the primary
/// Rebase/Merge button, plus a factual "merge details" summary. Hidden entirely
/// once the MR is merged/closed (the header pill conveys the terminal state).
class GitLabMrMergePanel extends StatelessWidget {
  const GitLabMrMergePanel({
    super.key,
    required this.ticket,
    required this.entity,
    required this.onApprove,
    required this.onMerge,
    required this.onRebase,
  });

  final Ticket ticket;
  final GitLabItemEntity entity;
  final VoidCallback onApprove;
  final VoidCallback onMerge;
  final VoidCallback onRebase;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final raw = ticket.providerStatus.toLowerCase();
    if (raw == 'merged' || raw == 'closed') return const SizedBox.shrink();

    final mergeStatus = humanizeMergeState(entity.mergeStatus);
    final commitsBehind = entity.commitsBehind ?? 0;
    final needsRebase =
        entity.mergeStatus == 'need_rebase' || commitsBehind > 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(context.radii.md),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(context.spacing.lg),
            child: Wrap(
              spacing: context.spacing.md,
              runSpacing: context.spacing.md,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(
                  needsRebase ? Icons.do_not_disturb_on_outlined : Icons.info,
                  size: context.spacing.xl4,
                  color: needsRebase ? c.error : c.info,
                ),
                Text(
                  needsRebase
                      ? l.mergeBlockedNeedRebase
                      : (mergeStatus.isEmpty
                            ? l.mergeReady
                            : l.mergeStatusValue(mergeStatus)),
                  style: context.typography.bodyStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
                AppButton.outlinedNeutral(
                  size: AppButtonSize.small,
                  onPressed: onApprove,
                  child: Text(l.approve),
                ),
                if (needsRebase)
                  AppButton.filled(
                    size: AppButtonSize.small,
                    onPressed: onRebase,
                    child: Text(l.rebase),
                  )
                else
                  AppButton.filled(
                    size: AppButtonSize.small,
                    onPressed: onMerge,
                    child: Text(l.gitlabMerge),
                  ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(context.spacing.lg),
            decoration: BoxDecoration(
              color: c.surfaceSubtle,
              border: Border(top: context.hairlineSide),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.mergeDetails,
                  style: context.typography.secondaryStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
                SizedBox(height: context.spacing.sm),
                if (commitsBehind > 0)
                  _DetailBullet(l.commitsBehindTarget(commitsBehind)),
                if ((entity.sourceBranch ?? '').isNotEmpty &&
                    (entity.targetBranch ?? '').isNotEmpty)
                  _DetailBullet(
                    '${entity.sourceBranch} → ${entity.targetBranch}',
                  ),
                if (mergeStatus.isNotEmpty)
                  _DetailBullet(l.mergeStatusValue(mergeStatus)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBullet extends StatelessWidget {
  const _DetailBullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: context.spacing.xs),
      child: Text(
        '• $text',
        style: context.typography.secondary.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
    );
  }
}
