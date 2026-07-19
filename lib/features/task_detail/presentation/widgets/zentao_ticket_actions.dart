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
import 'resolve_dialog.dart';

/// ZenTao: Assign always; for a bug, Resolve when it's active, or Activate
/// (reopen) when it's resolved/closed — mirroring ZenTao's own bug toolbar.
/// Activate applies optimistically and shows a snackbar result.
class ZenTaoActions extends ConsumerStatefulWidget {
  const ZenTaoActions({super.key, required this.ticket});
  final Ticket ticket;

  @override
  ConsumerState<ZenTaoActions> createState() => _ZenTaoActionsState();
}

class _ZenTaoActionsState extends ConsumerState<ZenTaoActions> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final ticket = widget.ticket;
    final isBug = (ticket.externalType ?? '').toLowerCase() == 'bug';
    final raw = ticket.providerStatus.toLowerCase();
    // A resolved/closed bug is reopened via ZenTao's "activate" action.
    final canReopen = isBug && (raw == 'resolved' || raw == 'closed');

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
          if (isBug && !canReopen) ...[
            SizedBox(width: context.spacing.md),
            DetailActionButton(
              icon: Icons.check_circle_outline,
              label: l.resolve,
              onTap: _busy
                  ? null
                  : () => showDialog<void>(
                      context: context,
                      builder: (_) => ResolveDialog(ticket: ticket),
                    ),
            ),
          ],
          if (canReopen) ...[
            SizedBox(width: context.spacing.md),
            DetailActionButton(
              icon: Icons.restart_alt,
              label: l.activate,
              onTap: _busy
                  ? null
                  : () => _run(
                      () => getIt<SyncService>().activateBug(
                        ticket,
                        build: 'trunk',
                      ),
                      'Activated bug #${ticket.externalKey}',
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
