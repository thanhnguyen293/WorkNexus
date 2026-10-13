import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/platform/open_external.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/relative_time.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../util/gitlab_mr_phase.dart';
import '../util/template_runs.dart';
import 'gitlab_mr_commands.dart';
import 'mr_async_button.dart';
import 'mr_widget_card.dart';

/// How a finished MR ended, as GitLab shows it: "Merged by X" with Revert /
/// Cherry-pick and the merge details, or "Closed by X" with Reopen. Nothing
/// while the MR is still open.
class GitLabMrOutcomePanel extends StatelessWidget {
  const GitLabMrOutcomePanel({
    super.key,
    required this.ticket,
    required this.entity,
    required this.commands,
  });

  final Ticket ticket;
  final GitLabItemEntity entity;
  final GitLabMrCommands commands;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final url = ticket.url ?? '';
    return switch (gitLabMrPhase(ticket, entity)) {
      GitLabMrPhase.merged => MrWidgetCard(
        icon: LucideIcons.gitMerge300,
        iconColor: c.info,
        tint: c.info,
        title: _ByLine(
          message: l.mrMergedBy,
          name: entity.mergedBy,
          at: entity.mergedAt,
          fallback: l.gitlabColMerged,
        ),
        // GitLab's revert / cherry-pick open a branch-picking flow that
        // creates a new MR, so they hand off to the web page.
        actions: [
          if (url.isNotEmpty) ...[
            AppButton.text(
              size: AppButtonSize.small,
              onPressed: () => openExternally(url),
              child: Text(l.mrRevert),
            ),
            AppButton.text(
              size: AppButtonSize.small,
              onPressed: () => openExternally(url),
              child: Text(l.mrCherryPick),
            ),
          ],
        ],
        details: _MergedDetails(entity: entity),
      ),
      GitLabMrPhase.closed => MrWidgetCard(
        icon: LucideIcons.gitPullRequestClosed300,
        iconColor: c.error,
        title: _ByLine(
          message: l.mrClosedBy,
          name: entity.closedBy,
          at: entity.closedAt,
          fallback: l.gitlabColClosed,
        ),
        actions: [
          MrAsyncButton(
            kind: MrButtonKind.secondary,
            label: l.reopenMergeRequest,
            onPressed: commands.reopen,
          ),
        ],
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

/// "Merged by **name** time" — the name in the accent, the time muted; just
/// [fallback] when the provider didn't say who.
class _ByLine extends ConsumerWidget {
  const _ByLine({
    required this.message,
    required this.name,
    required this.at,
    required this.fallback,
  });

  final String Function(String name, String when) message;
  final String? name;
  final DateTime? at;
  final String fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final name = this.name ?? '';
    if (name.isEmpty) return Text(fallback);
    final when = formatWhen(
      context,
      at,
      format: ref.watch(appSettingsProvider.select((s) => s.dateFormat)),
    );
    return Text.rich(
      TextSpan(
        children: [
          for (final run in templateRuns((m) => message(m[0], m[1]), 2))
            switch (run.slot) {
              0 => TextSpan(
                text: name,
                style: context.typography.bodyStrong.copyWith(color: c.accent),
              ),
              1 => TextSpan(
                text: when,
                style: context.typography.body.copyWith(color: c.textTertiary),
              ),
              _ => TextSpan(text: run.text),
            },
        ],
      ),
    );
  }
}

/// "Changes merged into `target` with `sha`.", whether the commits were
/// squashed, and whether the source branch went with it.
class _MergedDetails extends StatelessWidget {
  const _MergedDetails({required this.entity});

  final GitLabItemEntity entity;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final target = entity.targetBranch ?? '';
    final sha = entity.mergeCommitSha ?? entity.squashCommitSha ?? '';
    final mono = context.typography.mono.copyWith(color: c.textPrimary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.mergeDetails,
          style: context.typography.secondaryStrong.copyWith(
            color: c.textPrimary,
          ),
        ),
        if (target.isNotEmpty && sha.isNotEmpty)
          MrDetailBullet(
            child: Text.rich(
              TextSpan(
                children: [
                  for (final run in templateRuns(
                    (m) => l.mrChangesMergedInto(m[0], m[1]),
                    2,
                  ))
                    switch (run.slot) {
                      0 => TextSpan(text: target, style: mono),
                      1 => TextSpan(
                        text: sha.length > 8 ? sha.substring(0, 8) : sha,
                        style: mono.copyWith(color: c.accent),
                      ),
                      _ => TextSpan(text: run.text),
                    },
                ],
              ),
            ),
          ),
        if ((entity.squashCommitSha ?? '').isNotEmpty)
          MrDetailBullet(child: Text(l.mrCommitsSquashed)),
        if (entity.removeSourceBranch ?? false)
          MrDetailBullet(child: Text(l.mrSourceBranchDeleted)),
      ],
    );
  }
}
