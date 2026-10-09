import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/zentao_action.dart';
import '../../../../core/domain/value_objects/zentao_task_action_input.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/check_zentao_task_input.dart';
import 'action_dialog_scaffold.dart';
import 'zentao_action_looks.dart';

/// Runs a status action on a ZenTao task, asking what ZenTao's own form for it
/// does: the hours worked and left, who it goes to next, and a note.
class ZenTaoTaskActionDialog extends ConsumerStatefulWidget {
  const ZenTaoTaskActionDialog({
    super.key,
    required this.ticket,
    required this.action,
  });

  final Ticket ticket;
  final ZenTaoTaskAction action;

  @override
  ConsumerState<ZenTaoTaskActionDialog> createState() =>
      _ZenTaoTaskActionDialogState();
}

class _ZenTaoTaskActionDialogState
    extends ConsumerState<ZenTaoTaskActionDialog> {
  final _spent = TextEditingController();
  // A task keeps its hours left until it is finished, so they are offered
  // again; a finished task has none left, to be filled in on reopening.
  late final _left = TextEditingController(
    text: switch (_task?.left) {
      final left? when left > 0 => _hoursText(left),
      _ => '',
    },
  );
  final _note = TextEditingController();
  String? _assignee;
  bool _busy = false;

  ZenTaoTaskEntity? get _task => switch (widget.ticket.providerEntity) {
    final ZenTaoTaskEntity task => task,
    _ => null,
  };

  double get _logged => _task?.consumed ?? 0;

  ZenTaoTaskActionInput get _input => ZenTaoTaskActionInput(
    spent: _hours(_spent.text),
    left: _hours(_left.text),
    assignee: _assignee,
    comment: _note.text,
  );

  @override
  void dispose() {
    _spent.dispose();
    _left.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit(String label) async {
    final l = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ticket = widget.ticket;
    setState(() => _busy = true);
    final res = await ref
        .read(zenTaoWorkflowServiceProvider)
        .runTaskAction(ticket, widget.action, _input);
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(zenTaoActionOutcome(l, res, label, ticket.externalKey)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final action = widget.action;
    final look = zenTaoTaskActionLook(l, action);
    final problem = const CheckZenTaoTaskInput()((
      action: action,
      input: _input,
      logged: _logged,
    ));
    final asksHours = action.asksSpent || action.asksLeft;
    return ActionScaffold(
      emoji: look.emoji,
      title: l.zentaoActionTitle(look.label, widget.ticket.externalKey),
      submitLabel: look.label,
      busy: _busy,
      canSubmit: problem == null,
      onSubmit: () => _submit(look.label),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (asksHours) ...[
            if (_logged > 0) ...[
              Text(
                l.zentaoHoursLogged(_hoursText(_logged)),
                style: context.typography.bodySm.copyWith(
                  color: c.textSecondary,
                ),
              ),
              SizedBox(height: context.spacing.lg),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (action.asksSpent)
                  Expanded(
                    child: _HoursField(
                      label: l.zentaoHoursSpent,
                      controller: _spent,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                if (action.asksSpent && action.asksLeft)
                  SizedBox(width: context.spacing.lg),
                if (action.asksLeft)
                  Expanded(
                    child: _HoursField(
                      label: l.zentaoHoursLeft,
                      controller: _left,
                      onChanged: () => setState(() {}),
                    ),
                  ),
              ],
            ),
            if (problem != null) ...[
              SizedBox(height: context.spacing.md),
              Text(
                switch (problem) {
                  ZenTaoTaskInputProblem.invalidHours => l.zentaoHoursInvalid,
                  ZenTaoTaskInputProblem.leftRequired =>
                    l.zentaoHoursLeftRequired,
                  ZenTaoTaskInputProblem.spentRequired =>
                    l.zentaoHoursSpentRequired,
                },
                style: context.typography.bodySm.copyWith(
                  color: c.textTertiary,
                ),
              ),
            ],
            SizedBox(height: context.spacing.xl2),
          ],
          if (action.asksAssignee) ...[
            FieldLabel(l.zentaoAssignToOptional),
            AssigneeDropdown(
              ticketId: widget.ticket.id,
              value: _assignee,
              onChanged: (v) => setState(() => _assignee = v),
            ),
            SizedBox(height: context.spacing.xl2),
          ],
          FieldLabel(l.zentaoNote),
          NoteField(_note),
        ],
      ),
    );
  }
}

/// A labelled field for a number of hours.
class _HoursField extends StatelessWidget {
  const _HoursField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        TextField(
          controller: controller,
          onChanged: (_) => onChanged(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
          ],
          style: context.typography.body.copyWith(
            color: context.colors.textPrimary,
          ),
          decoration: dropDecoration(context),
        ),
      ],
    );
  }
}

/// Hours typed in a field: 0 when empty, NaN (refused) when not a number.
double _hours(String text) {
  final value = text.trim().replaceAll(',', '.');
  return value.isEmpty ? 0 : double.tryParse(value) ?? double.nan;
}

String _hoursText(double hours) => NumberFormat('0.##').format(hours);
