import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/zentao_bug_action.dart';
import 'action_dialog_scaffold.dart';
import 'zentao_action_looks.dart';

/// Confirms, closes or reopens a ZenTao bug, asking what ZenTao's own form
/// does: who it goes to next (default: me), the build it shows up in again,
/// and a note. Resolve has its own dialog.
class ZenTaoBugActionDialog extends ConsumerStatefulWidget {
  const ZenTaoBugActionDialog({
    super.key,
    required this.ticket,
    required this.action,
  }) : assert(action != ZenTaoBugAction.resolve, 'Resolve has its own dialog');

  final Ticket ticket;
  final ZenTaoBugAction action;

  @override
  ConsumerState<ZenTaoBugActionDialog> createState() =>
      _ZenTaoBugActionDialogState();
}

class _ZenTaoBugActionDialogState extends ConsumerState<ZenTaoBugActionDialog> {
  final _note = TextEditingController();
  final _build = TextEditingController(text: 'trunk');
  String? _assignee;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    _build.dispose();
    super.dispose();
  }

  Future<void> _submit(String label) async {
    final l = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final service = ref.read(zenTaoWorkflowServiceProvider);
    final ticket = widget.ticket;
    setState(() => _busy = true);
    final res = await switch (widget.action) {
      ZenTaoBugAction.confirm => service.confirmBug(
        ticket,
        assignee: _assignee,
        comment: _note.text,
      ),
      ZenTaoBugAction.activate => service.activateBug(
        ticket,
        build: _build.text,
        assignee: _assignee,
        comment: _note.text,
      ),
      ZenTaoBugAction.close => service.closeBug(ticket, comment: _note.text),
      ZenTaoBugAction.resolve => throw ArgumentError.value(
        widget.action,
        'action',
        'Resolve has its own dialog',
      ),
    };
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
    final look = zenTaoBugActionLook(l, widget.action);
    return ActionScaffold(
      emoji: look.emoji,
      title: l.zentaoActionTitle(look.label, widget.ticket.externalKey),
      submitLabel: look.label,
      busy: _busy,
      onSubmit: () => _submit(look.label),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.action == ZenTaoBugAction.activate) ...[
            FieldLabel(l.zentaoBuild),
            TextField(
              controller: _build,
              style: context.typography.body.copyWith(color: c.textPrimary),
              decoration: dropDecoration(context),
            ),
            SizedBox(height: context.spacing.xl2),
          ],
          if (widget.action != ZenTaoBugAction.close) ...[
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
