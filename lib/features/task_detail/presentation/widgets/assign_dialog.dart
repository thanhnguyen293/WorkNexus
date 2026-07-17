import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_spacing.dart';
import 'action_dialog_scaffold.dart';

/// Assigns a ticket to a provider user, with an optional note.
class AssignDialog extends ConsumerStatefulWidget {
  const AssignDialog({super.key, required this.ticket});
  final Ticket ticket;

  @override
  ConsumerState<AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends ConsumerState<AssignDialog> {
  final _note = TextEditingController();
  String? _assignee;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    final res = await ref
        .read(syncServiceProvider)
        .assignTicket(widget.ticket, assignee: _assignee!, comment: _note.text);
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          res.isOk
              ? 'Assigned to $_assignee'
              : 'Assign failed: ${res.failureOrNull?.message ?? 'error'}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ActionScaffold(
      emoji: '👤',
      title: 'Assign #${widget.ticket.externalKey}',
      submitLabel: 'Assign',
      busy: _busy,
      canSubmit: _assignee != null,
      onSubmit: _submit,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FieldLabel('Assign to'),
          AssigneeDropdown(
            ticketId: widget.ticket.id,
            value: _assignee,
            onChanged: (v) => setState(() => _assignee = v),
          ),
          SizedBox(height: context.spacing.xl2),
          const FieldLabel('Note'),
          NoteField(_note),
        ],
      ),
    );
  }
}
