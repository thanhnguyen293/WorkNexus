import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../domain/value_objects/provider_type.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A merge request / pull request state chip (Open / Draft / Merged /
/// Closed), colour-coded from the provider's raw [status] and worded the
/// way [provider] (GitLab or GitHub) words it.
class MergeRequestStatePill extends StatelessWidget {
  const MergeRequestStatePill({
    super.key,
    required this.status,
    required this.provider,
  });

  final String status;
  final ProviderType provider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final gitlab = provider == ProviderType.gitlab;
    final (color, label) = switch (status.toLowerCase()) {
      'merged' => (c.info, gitlab ? l.gitlabColMerged : l.githubColMerged),
      'closed' => (
        c.textTertiary,
        gitlab ? l.gitlabColClosed : l.githubColClosed,
      ),
      'draft' => (c.warning, gitlab ? l.gitlabColDraft : l.githubColDraft),
      _ => (c.success, gitlab ? l.gitlabColOpen : l.githubColOpen),
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
            gitlab ? Icons.account_tree_outlined : Icons.merge_type,
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
