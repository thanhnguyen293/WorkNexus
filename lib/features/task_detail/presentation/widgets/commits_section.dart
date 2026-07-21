import 'package:flutter/material.dart';

import '../../../../core/domain/value_objects/repo_change.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/relative_time.dart';
import '../../../../l10n/app_localizations.dart';

typedef CommitsLoader = Future<Result<List<RepoCommit>>> Function();

/// Lists the commits on a merge request / pull request (loaded on demand). Shared
/// by the GitLab MR and GitHub PR two-pane details.
class CommitsSection extends StatefulWidget {
  const CommitsSection({super.key, required this.loader});

  final CommitsLoader loader;

  @override
  State<CommitsSection> createState() => _CommitsSectionState();
}

class _CommitsSectionState extends State<CommitsSection> {
  late final Future<Result<List<RepoCommit>>> _future = widget.loader();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    return FutureBuilder<Result<List<RepoCommit>>>(
      future: _future,
      builder: (context, snap) {
        final res = snap.data;
        final commits = res is Ok<List<RepoCommit>> ? res.value : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l.commits,
                  style: context.typography.display.copyWith(
                    color: c.textPrimary,
                  ),
                ),
                if (commits != null && commits.isNotEmpty) ...[
                  SizedBox(width: context.spacing.sm),
                  _CountBadge(commits.length),
                ],
              ],
            ),
            SizedBox(height: context.spacing.lg),
            if (snap.connectionState != ConnectionState.done)
              const _Loading()
            else if (res is Err<List<RepoCommit>>)
              _Muted(res.failure.message)
            else if (commits == null || commits.isEmpty)
              _Muted(l.noCommits)
            else
              for (final commit in commits) _CommitRow(commit),
          ],
        );
      },
    );
  }
}

class _CommitRow extends StatelessWidget {
  const _CommitRow(this.commit);

  final RepoCommit commit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final meta = [
      if ((commit.author ?? '').isNotEmpty) commit.author!,
      if (commit.date != null) formatWhen(context, commit.date),
    ].join(' · ');
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.spacing.sm,
              vertical: context.spacing.xs,
            ),
            decoration: BoxDecoration(
              color: c.surfaceSubtle,
              borderRadius: BorderRadius.circular(context.radii.sm),
            ),
            child: Text(
              commit.shortSha,
              style: context.typography.mono.copyWith(color: c.accent),
            ),
          ),
          SizedBox(width: context.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  commit.title,
                  style: context.typography.body.copyWith(color: c.textPrimary),
                ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    style: context.typography.meta.copyWith(
                      color: c.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);

  final int count;

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
        borderRadius: BorderRadius.circular(context.radii.md),
      ),
      child: Text(
        '$count',
        style: context.typography.captionStrong.copyWith(
          color: c.textSecondary,
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.md),
      child: SizedBox(
        height: context.spacing.xl4,
        width: context.spacing.xl4,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.md),
      child: Text(
        text,
        style: context.typography.secondary.copyWith(
          color: context.colors.textTertiary,
        ),
      ),
    );
  }
}
