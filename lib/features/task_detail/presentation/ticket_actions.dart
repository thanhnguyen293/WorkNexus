import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/domain/entities/ticket.dart';
import '../../../core/domain/value_objects/provider_type.dart';
import '../../../core/error/result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../sync/data/sync_service.dart';
import 'widgets/assign_dialog.dart';
import 'widgets/resolve_dialog.dart';

/// The action row shown under the detail header, dispatched by provider. Only
/// providers whose write actions are implemented render anything.
class TicketActionsBar extends StatelessWidget {
  const TicketActionsBar({super.key, required this.ticket});
  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    return switch (ticket.providerType) {
      ProviderType.zentao => _ZenTaoActions(ticket: ticket),
      ProviderType.gitlab => _GitLabActions(ticket: ticket),
      ProviderType.github || ProviderType.jira => const SizedBox.shrink(),
    };
  }
}

/// ZenTao: Assign + (for bugs) Resolve, each opening a dialog.
class _ZenTaoActions extends StatelessWidget {
  const _ZenTaoActions({required this.ticket});
  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final isBug = (ticket.externalType ?? '').toLowerCase() == 'bug';
    return Padding(
      padding: EdgeInsets.only(top: context.spacing.xl),
      child: Row(
        children: [
          _ActionButton(
            icon: Icons.person_add_alt_1_outlined,
            label: 'Assign',
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => AssignDialog(ticket: ticket),
            ),
          ),
          if (isBug) ...[
            SizedBox(width: context.spacing.md),
            _ActionButton(
              icon: Icons.check_circle_outline,
              label: 'Resolve',
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => ResolveDialog(ticket: ticket),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// GitLab: Assign, plus Close/Reopen (issues) or Merge/Close/Reopen (MRs),
/// gated on the raw provider status. Actions apply optimistically and show a
/// snackbar result; a merged MR is terminal (no state actions).
class _GitLabActions extends ConsumerStatefulWidget {
  const _GitLabActions({required this.ticket});
  final Ticket ticket;

  @override
  ConsumerState<_GitLabActions> createState() => _GitLabActionsState();
}

class _GitLabActionsState extends ConsumerState<_GitLabActions> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final ticket = widget.ticket;
    final isMr = (ticket.externalType ?? '').toLowerCase() == 'mergerequest';
    final raw = ticket.providerStatus.toLowerCase();
    final isClosed = raw == 'closed';
    final isMerged = raw == 'merged';

    return Padding(
      padding: EdgeInsets.only(top: context.spacing.xl),
      child: Row(
        children: [
          _ActionButton(
            icon: Icons.person_add_alt_1_outlined,
            label: l.assign,
            onTap: _busy
                ? null
                : () => showDialog<void>(
                    context: context,
                    builder: (_) => AssignDialog(ticket: ticket),
                  ),
          ),
          if (isMr && !isClosed && !isMerged) ...[
            SizedBox(width: context.spacing.md),
            _ActionButton(
              icon: Icons.merge_type,
              label: l.gitlabMerge,
              onTap: _busy
                  ? null
                  : () => _run(
                      () => getIt<SyncService>().mergeGitLabMr(ticket),
                      'Merged !${ticket.externalKey}',
                    ),
            ),
          ],
          if (!isClosed && !isMerged) ...[
            SizedBox(width: context.spacing.md),
            _ActionButton(
              icon: Icons.check_circle_outline,
              label: l.close,
              onTap: _busy
                  ? null
                  : () => _run(
                      () => getIt<SyncService>().closeGitLabItem(ticket),
                      'Closed #${ticket.externalKey}',
                    ),
            ),
          ],
          if (isClosed) ...[
            SizedBox(width: context.spacing.md),
            _ActionButton(
              icon: Icons.refresh,
              label: l.gitlabReopen,
              onTap: _busy
                  ? null
                  : () => _run(
                      () => getIt<SyncService>().reopenGitLabItem(ticket),
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppButton.outlinedNeutral(
      size: AppButtonSize.small,
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          SizedBox(width: context.spacing.sm),
          Text(label),
        ],
      ),
    );
  }
}
