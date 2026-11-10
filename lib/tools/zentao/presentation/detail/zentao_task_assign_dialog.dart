import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/locator.dart';
import '../../../../core/domain/adapters/ticket_detail_service.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/util/hours_text.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/detail/presentation/widgets/action_dialog_scaffold.dart';
import '../../../../shared/detail/presentation/widgets/ticket_note_field.dart';
import '../../domain/usecases/check_zentao_assign_left.dart';
import 'task_hours_field.dart';
import 'task_input_problem_text.dart';

/// Assigns a ZenTao task as ZenTao's own form does: who it goes to, the hours
/// left (required until the task is done) and a note.
class ZenTaoTaskAssignDialog extends ConsumerStatefulWidget {
  const ZenTaoTaskAssignDialog({super.key, required this.ticket});

  final Ticket ticket;

  @override
  ConsumerState<ZenTaoTaskAssignDialog> createState() =>
      _ZenTaoTaskAssignDialogState();
}

class _ZenTaoTaskAssignDialogState
    extends ConsumerState<ZenTaoTaskAssignDialog> {
  late final _note = TicketNoteController(widget.ticket);
  // Prefilled with what the task has left, as ZenTao's form is.
  late final _left = TextEditingController(
    text: switch (widget.ticket.providerEntity) {
      ZenTaoTaskEntity(:final left?) when left > 0 => hoursText(left),
      _ => '',
    },
  );
  String? _assignee;
  bool _busy = false;

  // ZenTao hides the hours left on a done task: it has none to hand over.
  bool get _asksLeft =>
      widget.ticket.providerStatus.trim().toLowerCase() != 'done';

  @override
  void dispose() {
    _note.dispose();
    _left.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final assignee = _assignee;
    if (assignee == null) return;
    final l = AppL10n.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    final res = await getIt<TicketDetailService>().assignTicket(
      widget.ticket,
      assignee: assignee,
      comment: _note.value,
      left: _asksLeft ? parseHours(_left.text) : null,
    );
    if (!mounted) return;
    showAppSnack(
      context,
      res.isOk
          ? l.taskDetailAssignedTo(assignee)
          : l.actionFailed(
              res.failureOrNull?.message ?? l.providerActionFailed,
            ),
      isError: !res.isOk,
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final problem = _asksLeft
        ? const CheckZenTaoAssignLeft()(parseHours(_left.text))
        : null;
    return ActionScaffold(
      title: l.zentaoActionTitle(l.assign, widget.ticket.externalKey),
      submitLabel: l.assign,
      icon: LucideIcons.userPlus300,
      busy: _busy,
      canSubmit: _assignee != null && problem == null,
      onSubmit: _submit,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(l.fieldAssignTo),
          AssigneeDropdown(
            ticketId: widget.ticket.id,
            value: _assignee,
            onChanged: (v) => setState(() => _assignee = v),
          ),
          SizedBox(height: s.xl2),
          if (_asksLeft) ...[
            TaskHoursField(
              label: l.zentaoHoursLeft,
              controller: _left,
              onChanged: () => setState(() {}),
            ),
            if (problem != null) TaskInputProblemText(problem),
            SizedBox(height: s.xl2),
          ],
          FieldLabel(l.zentaoNote),
          TicketNoteField(ticket: widget.ticket, controller: _note),
        ],
      ),
    );
  }
}
