import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../sync/data/sync_service.dart';
import 'assign_dialog.dart';
import 'detail_action_button.dart';

/// GitHub: Assign, plus Close/Reopen (issues) or Merge/Close/Reopen (PRs), gated
/// on the raw provider status. Actions apply optimistically and show a snackbar
/// result; a merged PR is terminal (no state actions).
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

    return Padding(
      padding: EdgeInsets.only(top: context.spacing.xl),
      child: Row(
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
          if (isPr && !isClosed && !isMerged) ...[
            SizedBox(width: context.spacing.md),
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
          ],
          if (!isClosed && !isMerged) ...[
            SizedBox(width: context.spacing.md),
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
          ],
          if (isClosed) ...[
            SizedBox(width: context.spacing.md),
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
