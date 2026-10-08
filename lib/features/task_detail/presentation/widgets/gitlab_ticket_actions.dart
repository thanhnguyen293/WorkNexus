import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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

/// GitLab: Assign, plus Close/Reopen (issues) or Reviewers/Rebase/Merge/Close/
/// Reopen (MRs), gated on the raw provider status and merge status. Actions apply
/// optimistically and show a snackbar result; a merged MR is terminal (no state
/// actions).
class GitLabActions extends ConsumerStatefulWidget {
  const GitLabActions({super.key, required this.ticket});
  final Ticket ticket;

  @override
  ConsumerState<GitLabActions> createState() => _GitLabActionsState();
}

class _GitLabActionsState extends ConsumerState<GitLabActions> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final ticket = widget.ticket;
    final isMr = (ticket.externalType ?? '').toLowerCase() == 'mergerequest';
    final raw = ticket.providerStatus.toLowerCase();
    final isClosed = raw == 'closed';
    final isMerged = raw == 'merged';
    final active = !isClosed && !isMerged;
    final mergeStatus = switch (ticket.providerEntity) {
      GitLabItemEntity(:final mergeStatus) => mergeStatus,
      _ => null,
    };
    final needsRebase = isMr && active && mergeStatus == 'need_rebase';

    return Padding(
      padding: EdgeInsets.only(top: context.spacing.xl),
      child: Wrap(
        spacing: context.spacing.md,
        runSpacing: context.spacing.md,
        children: [
          DetailActionButton(
            icon: PhosphorIconsLight.userPlus,
            label: l.assign,
            onTap: _busy
                ? null
                : () => showDialog<void>(
                    context: context,
                    builder: (_) => AssignDialog(ticket: ticket),
                  ),
          ),
          if (isMr && active)
            DetailActionButton(
              icon: PhosphorIconsLight.notePencil,
              label: l.reviewers,
              onTap: _busy
                  ? null
                  : () => showDialog<void>(
                      context: context,
                      builder: (_) => ReviewersDialog(ticket: ticket),
                    ),
            ),
          if (needsRebase)
            DetailActionButton(
              icon: PhosphorIconsLight.arrowsClockwise,
              label: l.rebase,
              onTap: _busy
                  ? null
                  : () => _run(
                      () => getIt<SyncService>().rebaseGitLabMr(ticket),
                      'Rebased !${ticket.externalKey}',
                    ),
            ),
          if (isMr && active)
            DetailActionButton(
              icon: PhosphorIconsLight.gitMerge,
              label: l.gitlabMerge,
              onTap: _busy
                  ? null
                  : () => _run(
                      () => getIt<SyncService>().mergeGitLabMr(ticket),
                      'Merged !${ticket.externalKey}',
                    ),
            ),
          if (active)
            DetailActionButton(
              icon: PhosphorIconsLight.checkCircle,
              label: l.close,
              onTap: _busy
                  ? null
                  : () => _run(
                      () => getIt<SyncService>().closeGitLabItem(ticket),
                      'Closed #${ticket.externalKey}',
                    ),
            ),
          if (isClosed)
            DetailActionButton(
              icon: PhosphorIconsLight.arrowClockwise,
              label: l.gitlabReopen,
              onTap: _busy
                  ? null
                  : () => _run(
                      () => getIt<SyncService>().reopenGitLabItem(ticket),
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
