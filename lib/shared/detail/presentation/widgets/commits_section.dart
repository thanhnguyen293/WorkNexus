import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/value_objects/repo_change.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/relative_time.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../l10n/app_localizations.dart';
import 'detail_section_title.dart';

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
  late Future<Result<List<RepoCommit>>> _future = widget.loader();

  void _retry() => setState(() => _future = widget.loader());

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return FutureBuilder<Result<List<RepoCommit>>>(
      future: _future,
      builder: (context, snap) {
        final res = snap.data;
        final commits = res is Ok<List<RepoCommit>> ? res.value : null;
        final Widget body;
        if (snap.hasError) {
          body = AppStateView.error(compact: true, onRetry: _retry);
        } else if (snap.connectionState != ConnectionState.done) {
          body = const AppStateView.loading(compact: true);
        } else if (res case Err<List<RepoCommit>>(:final failure)) {
          body = AppStateView.error(
            compact: true,
            message: failure.message,
            onRetry: _retry,
          );
        } else if (commits == null || commits.isEmpty) {
          body = AppStateView.empty(
            compact: true,
            icon: LucideIcons.gitCommitHorizontal300,
            title: l.noCommits,
          );
        } else {
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final commit in commits) _CommitRow(commit)],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DetailSectionTitle(l.commits, count: commits?.length),
            body,
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
