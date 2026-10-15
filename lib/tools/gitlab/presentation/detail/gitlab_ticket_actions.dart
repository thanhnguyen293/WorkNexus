import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/locator.dart';
import '../../../../core/domain/adapters/gitlab_mr_service.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/detail/presentation/widgets/assign_dialog.dart';
import '../../../../shared/detail/presentation/widgets/detail_action_button.dart';
import '../../../../shared/detail/presentation/widgets/reviewers_dialog.dart';

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

    return Wrap(
      spacing: context.spacing.md,
      runSpacing: context.spacing.md,
      children: [
        DetailActionButton(
          icon: LucideIcons.userPlus300,
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
            icon: LucideIcons.squarePen300,
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
            icon: LucideIcons.refreshCw300,
            label: l.rebase,
            onTap: _busy
                ? null
                : () => _run(
                    () => getIt<GitLabMrService>().rebaseGitLabMr(ticket),
                    l.taskDetailRebased('!${ticket.externalKey}'),
                  ),
          ),
        if (isMr && active)
          DetailActionButton(
            icon: LucideIcons.gitMerge300,
            label: l.gitlabMerge,
            onTap: _busy
                ? null
                : () => _run(
                    () => getIt<GitLabMrService>().mergeGitLabMr(ticket),
                    l.taskDetailMerged('!${ticket.externalKey}'),
                  ),
          ),
        if (active)
          DetailActionButton(
            icon: LucideIcons.checkCircle300,
            label: l.close,
            onTap: _busy
                ? null
                : () => _run(
                    () => getIt<GitLabMrService>().closeGitLabItem(ticket),
                    l.taskDetailClosed('#${ticket.externalKey}'),
                  ),
          ),
        if (isClosed)
          DetailActionButton(
            icon: LucideIcons.rotateCw300,
            label: l.gitlabReopen,
            onTap: _busy
                ? null
                : () => _run(
                    () => getIt<GitLabMrService>().reopenGitLabItem(ticket),
                    l.taskDetailReopened('#${ticket.externalKey}'),
                  ),
          ),
      ],
    );
  }

  Future<void> _run(
    Future<Result<void>> Function() action,
    String okMessage,
  ) async {
    final l = AppL10n.of(context);
    setState(() => _busy = true);
    final res = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    showAppSnack(
      context,
      res.isOk
          ? okMessage
          : l.actionFailed(
              res.failureOrNull?.message ?? l.providerActionFailed,
            ),
      isError: !res.isOk,
    );
  }
}
