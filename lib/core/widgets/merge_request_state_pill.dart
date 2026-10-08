import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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
    final (color, label) = mergeRequestState(context, status, provider);
    final gitlab = provider == ProviderType.gitlab;
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
            gitlab
                ? PhosphorIconsLight.treeStructure
                : PhosphorIconsLight.gitMerge,
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

/// Colour and wording of a merge request / pull request state (Open /
/// Draft / Merged / Closed) from the provider's raw [status], worded the way
/// [provider] words it.
(Color, String) mergeRequestState(
  BuildContext context,
  String status,
  ProviderType provider,
) {
  final c = context.colors;
  final l = AppL10n.of(context);
  final gitlab = provider == ProviderType.gitlab;
  return switch (status.toLowerCase()) {
    'merged' => (c.info, gitlab ? l.gitlabColMerged : l.githubColMerged),
    'closed' => (
      c.textTertiary,
      gitlab ? l.gitlabColClosed : l.githubColClosed,
    ),
    'draft' => (c.warning, gitlab ? l.gitlabColDraft : l.githubColDraft),
    _ => (c.success, gitlab ? l.gitlabColOpen : l.githubColOpen),
  };
}
