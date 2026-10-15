import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/entities/zentao_ticket_form.dart';
import '../../../../core/domain/value_objects/zentao_action.dart';
import '../../../../core/domain/value_objects/zentao_task_action_input.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/hours_text.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/attachments_input.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/detail/presentation/widgets/action_dialog_scaffold.dart';
import '../../domain/usecases/check_zentao_task_input.dart';
import 'task_action_date_field.dart';
import 'task_hours_field.dart';
import 'zentao_action_looks.dart';

/// Runs a status action on a ZenTao task, asking what ZenTao's own form for it
/// does: the hours worked and left, who it goes to next, when work really
/// began and ended, files and a note.
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
      final left? when left > 0 => hoursText(left),
      _ => '',
    },
  );
  final _note = TextEditingController();
  // Preset as ZenTao's forms are: starting keeps the task with its holder,
  // finishing hands it back to its creator.
  late String? _assignee = switch (widget.action) {
    ZenTaoTaskAction.finish => _task?.openedByHandle,
    ZenTaoTaskAction.start ||
    ZenTaoTaskAction.restart => widget.ticket.assignee,
    _ => null,
  };
  // One "now" for both, so the default end is never before the begin.
  final _opened = DateTime.now();
  late DateTime _began = _task?.realStarted ?? _opened;
  late DateTime _ended = _began.isAfter(_opened) ? _began : _opened;
  List<DraftFile> _files = const [];
  bool _busy = false;

  ZenTaoTaskEntity? get _task => switch (widget.ticket.providerEntity) {
    final ZenTaoTaskEntity task => task,
    _ => null,
  };

  double get _logged => _task?.consumed ?? 0;

  ZenTaoTaskActionInput get _input => ZenTaoTaskActionInput(
    spent: parseHours(_spent.text),
    left: parseHours(_left.text),
    assignee: _assignee,
    began: widget.action.asksBegin ? _began : null,
    ended: widget.action.asksEnd ? _ended : null,
    files: _files,
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
    final navigator = Navigator.of(context);
    final ticket = widget.ticket;
    setState(() => _busy = true);
    final res = await ref
        .read(zenTaoWorkflowServiceProvider)
        .runTaskAction(ticket, widget.action, _input);
    if (!mounted) return;
    showAppSnack(
      context,
      zenTaoActionOutcome(l, res, label, ticket.externalKey),
      isError: !res.isOk,
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final action = widget.action;
    final look = zenTaoTaskActionLook(l, action);
    final input = _input;
    final problem = const CheckZenTaoTaskInput()((
      action: action,
      input: input,
      logged: _logged,
    ));
    final asksHours = action.asksSpent || action.asksLeft;
    void changed() => setState(() {});
    return ActionScaffold(
      title: l.zentaoActionTitle(look.label, widget.ticket.externalKey),
      submitLabel: look.label,
      icon: look.icon,
      busy: _busy,
      canSubmit: problem == null,
      onSubmit: () => _submit(look.label),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (asksHours) ...[
            if (action.asksSpent)
              // ZenTao's "already cost / total cost": the total follows the
              // hours typed for this time.
              _Hint(
                [
                  if (_logged > 0) l.zentaoHoursLogged(hoursText(_logged)),
                  if (input.spent > 0 && !input.spent.isNaN)
                    l.zentaoHoursTotal(hoursText(_logged + input.spent)),
                ].join(' · '),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (action.asksSpent)
                  Expanded(
                    child: TaskHoursField(
                      label: l.zentaoHoursSpent,
                      controller: _spent,
                      onChanged: changed,
                    ),
                  ),
                if (action.asksSpent && action.asksLeft) SizedBox(width: s.lg),
                if (action.asksLeft)
                  Expanded(
                    child: TaskHoursField(
                      label: l.zentaoHoursLeft,
                      controller: _left,
                      onChanged: changed,
                    ),
                  ),
              ],
            ),
            if (problem != null &&
                problem != ZenTaoTaskInputProblem.endBeforeBegin)
              _Problem(problem),
            SizedBox(height: s.xl2),
          ],
          if (action.asksAssignee) ...[
            FieldLabel(l.zentaoAssignToOptional),
            AssigneeDropdown(
              ticketId: widget.ticket.id,
              value: _assignee,
              onChanged: (v) => setState(() => _assignee = v),
            ),
            SizedBox(height: s.xl2),
          ],
          if (action.asksBegin || action.asksEnd) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (action.asksBegin)
                  Expanded(
                    child: TaskActionDateField(
                      label: l.zentaoActualBegin,
                      value: _began,
                      // Finishing keeps a begin already recorded, as ZenTao.
                      enabled: !action.asksEnd || _task?.realStarted == null,
                      onChanged: (v) => setState(() => _began = v),
                    ),
                  ),
                if (action.asksBegin && action.asksEnd) SizedBox(width: s.lg),
                if (action.asksEnd)
                  Expanded(
                    child: TaskActionDateField(
                      label: l.zentaoActualEnd,
                      value: _ended,
                      onChanged: (v) => setState(() => _ended = v),
                    ),
                  ),
              ],
            ),
            if (problem == ZenTaoTaskInputProblem.endBeforeBegin)
              const _Problem(ZenTaoTaskInputProblem.endBeforeBegin),
            SizedBox(height: s.xl2),
          ],
          if (action.asksFiles) ...[
            FieldLabel(l.zentaoFiles),
            AttachmentsInput(
              files: const [],
              newFiles: _files,
              onFilesChanged: (_) {},
              onNewFilesChanged: (v) => setState(() => _files = v),
            ),
            SizedBox(height: s.xl2),
          ],
          FieldLabel(l.zentaoNote),
          NoteField(_note),
        ],
      ),
    );
  }
}

/// Quiet context above the hours fields; nothing when [text] is empty.
class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.lg),
      child: Text(
        text,
        style: context.typography.bodySm.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
    );
  }
}

/// Why the input would be refused, under the fields it is about.
class _Problem extends StatelessWidget {
  const _Problem(this.problem);

  final ZenTaoTaskInputProblem problem;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Padding(
      padding: EdgeInsets.only(top: context.spacing.md),
      child: Text(
        switch (problem) {
          ZenTaoTaskInputProblem.invalidHours => l.zentaoHoursInvalid,
          ZenTaoTaskInputProblem.leftRequired => l.zentaoHoursLeftRequired,
          ZenTaoTaskInputProblem.spentRequired => l.zentaoHoursSpentRequired,
          ZenTaoTaskInputProblem.endBeforeBegin => l.zentaoEndBeforeBegin,
        },
        style: context.typography.bodySm.copyWith(
          color: context.colors.textTertiary,
        ),
      ),
    );
  }
}
