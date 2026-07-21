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

/// The GitHub PR merge widget. Open PR → mergeable state + "Update branch" (when
/// `behind`) and Merge; closed (not merged) PR → Reopen; merged → hidden (the
/// header pill conveys the terminal state). GitHub's PAT API has no approve or
/// true rebase, so neither is offered.
class GitHubPrMergePanel extends StatelessWidget {
  const GitHubPrMergePanel({
    super.key,
    required this.ticket,
    required this.entity,
    required this.onMerge,
    required this.onUpdateBranch,
    required this.onReopen,
  });

  final Ticket ticket;
  final GitHubItemEntity entity;
  final VoidCallback onMerge;
  final VoidCallback onUpdateBranch;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final raw = ticket.providerStatus.toLowerCase();
    if (raw == 'merged') return const SizedBox.shrink();

    final decoration = BoxDecoration(
      color: c.card,
      borderRadius: BorderRadius.circular(context.radii.md),
      border: Border.all(color: c.border),
    );

    if (raw == 'closed') {
      return DecoratedBox(
        decoration: decoration,
        child: Padding(
          padding: EdgeInsets.all(context.spacing.lg),
          child: Wrap(
            spacing: context.spacing.md,
            runSpacing: context.spacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(Icons.info, size: context.spacing.xl4, color: c.info),
              Text(
                l.prClosed,
                style: context.typography.bodyStrong.copyWith(
                  color: c.textPrimary,
                ),
              ),
              AppButton.filled(
                size: AppButtonSize.small,
                onPressed: onReopen,
                child: Text(l.githubReopen),
              ),
            ],
          ),
        ),
      );
    }

    final mergeStatus = humanizeMergeState(entity.mergeableState);
    final needsUpdate = (entity.mergeableState ?? '').toLowerCase() == 'behind';
    return DecoratedBox(
      decoration: decoration,
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
                  needsUpdate ? Icons.do_not_disturb_on_outlined : Icons.info,
                  size: context.spacing.xl4,
                  color: needsUpdate ? c.warning : c.info,
                ),
                Text(
                  needsUpdate
                      ? l.prBehindBase
                      : (mergeStatus.isEmpty
                            ? l.mergeReady
                            : l.mergeStatusValue(mergeStatus)),
                  style: context.typography.bodyStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
                if (needsUpdate)
                  AppButton.outlinedNeutral(
                    size: AppButtonSize.small,
                    onPressed: onUpdateBranch,
                    child: Text(l.updateBranch),
                  ),
                AppButton.filled(
                  size: AppButtonSize.small,
                  onPressed: onMerge,
                  child: Text(l.githubMerge),
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
                if ((entity.headBranch ?? '').isNotEmpty &&
                    (entity.baseBranch ?? '').isNotEmpty)
                  _DetailBullet('${entity.headBranch} → ${entity.baseBranch}'),
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
