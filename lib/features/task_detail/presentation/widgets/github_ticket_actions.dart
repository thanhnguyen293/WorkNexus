import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../sync/data/sync_service.dart';
import 'assign_dialog.dart';
import 'detail_action_button.dart';
import 'reviewers_dialog.dart';

/// GitHub: Assign, plus Close/Reopen (issues) or Reviewers/Update-branch/Merge/
/// Close/Reopen (PRs), gated on the raw provider status and mergeable state.
/// Actions apply optimistically and show a snackbar result; a merged PR is
/// terminal (no state actions).
class GitHubActions extends ConsumerStatefulWidget {
  const GitHubActions({super.key, required this.ticket});
  final Ticket ticket;

  @override
  ConsumerState<GitHubActions> createState() => _GitHubActionsState();
}

class _GitHubActionsState extends ConsumerState<GitHubActions> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final ticket = widget.ticket;
    final isPr = (ticket.externalType ?? '').toLowerCase() == 'pullrequest';
    final raw = ticket.providerStatus.toLowerCase();
    final isClosed = raw == 'closed';
    final isMerged = raw == 'merged';
    final active = !isClosed && !isMerged;
    final mergeableState = switch (ticket.providerEntity) {
      GitHubItemEntity(:final mergeableState) => mergeableState,
      _ => null,
    };
    // GitHub marks a PR whose base has moved ahead as `behind`; "Update branch"
    // (merge base into head) is GitHub's fix — it has no true rebase via the API.
    final needsUpdate = isPr && active && mergeableState == 'behind';

    return Padding(
      padding: EdgeInsets.only(top: context.spacing.xl),
      child: Wrap(
        spacing: context.spacing.md,
        runSpacing: context.spacing.md,
        children: [
          DetailActionButton(
            icon: Icons.person_add_alt_1_outlined,
            label: l.assign,
            onTap: _busy
                ? null
                : () => showDialog<void>(
                    context: context,
                    builder: (_) => AssignDialog(ticket: ticket),
                  ),
          ),
          if (isPr && active)
            DetailActionButton(
              icon: Icons.rate_review_outlined,
              label: l.reviewers,
              onTap: _busy
                  ? null
                  : () => showDialog<void>(
                      context: context,
                      builder: (_) => ReviewersDialog(ticket: ticket),
                    ),
            ),
          if (needsUpdate)
            DetailActionButton(
              icon: Icons.sync,
              label: l.updateBranch,
              onTap: _busy
                  ? null
                  : () => _run(
                      () => getIt<SyncService>().updateGitHubPrBranch(ticket),
                      'Updated #${ticket.externalKey}',
                    ),
            ),
          if (isPr && active)
            DetailActionButton(
              icon: Icons.merge_type,
              label: l.githubMerge,
              onTap: _busy
                  ? null
                  : () => _run(
                      () => getIt<SyncService>().mergeGitHubPr(ticket),
                      'Merged #${ticket.externalKey}',
                    ),
            ),
          if (active)
            DetailActionButton(
              icon: Icons.check_circle_outline,
              label: l.close,
              onTap: _busy
                  ? null
                  : () => _run(
                      () => getIt<SyncService>().closeGitHubItem(ticket),
                      'Closed #${ticket.externalKey}',
                    ),
            ),
          if (isClosed)
            DetailActionButton(
              icon: Icons.refresh,
              label: l.githubReopen,
              onTap: _busy
                  ? null
                  : () => _run(
                      () => getIt<SyncService>().reopenGitHubItem(ticket),
                      'Reopened #${ticket.externalKey}',
                    ),
            ),
        ],
      ),
    );
  }

  Future<void> _run(
    Future<Result<void>> Function() action,
    String okMessage,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final res = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          res.isOk
              ? okMessage
              : 'Failed: ${res.failureOrNull?.message ?? 'error'}',
        ),
      ),
    );
  }
}
