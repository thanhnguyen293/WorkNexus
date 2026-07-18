import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../sync/data/sync_service.dart';
import 'action_dialog_scaffold.dart';

/// ZenTao bug resolution codes → labels (ZenTao's own set).
const _resolutions = <String, String>{
  'fixed': 'Fixed',
  'bydesign': 'By design',
  'duplicate': 'Duplicate',
  'external': 'External',
  'notrepro': 'Irreproducible',
  'willnotfix': "Won't fix",
  'postponed': 'Postponed',
  'tostory': 'To story',
};

/// Resolves a ZenTao bug: resolution code, build, optional assignee + note.
class ResolveDialog extends ConsumerStatefulWidget {
  const ResolveDialog({super.key, required this.ticket});
  final Ticket ticket;

  @override
  ConsumerState<ResolveDialog> createState() => _ResolveDialogState();
}

class _ResolveDialogState extends ConsumerState<ResolveDialog> {
  final _note = TextEditingController();
  final _build = TextEditingController(text: 'trunk');
  String? _resolution;
  String? _assignee;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    _build.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    final res = await getIt<SyncService>().resolveBug(
      widget.ticket,
      resolution: _resolution!,
      build: _build.text,
      assignee: _assignee,
      comment: _note.text,
    );
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          res.isOk
              ? 'Resolved (${_resolutions[_resolution] ?? _resolution})'
              : 'Resolve failed: ${res.failureOrNull?.message ?? 'error'}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ActionScaffold(
      emoji: '✅',
      title: 'Resolve #${widget.ticket.externalKey}',
      submitLabel: 'Resolve',
      busy: _busy,
      canSubmit: _resolution != null,
      onSubmit: _submit,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FieldLabel('Resolution *'),
          DropdownButtonFormField<String>(
            initialValue: _resolution,
            isExpanded: true,
            dropdownColor: c.surface,
            decoration: dropDecoration(context),
            hint: Text(
              'Select a resolution',
              style: context.typography.body.copyWith(color: c.textTertiary),
            ),
            style: context.typography.body.copyWith(color: c.textPrimary),
            items: [
              for (final e in _resolutions.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _resolution = v),
          ),
          SizedBox(height: context.spacing.xl2),
          const FieldLabel('Build'),
          TextField(
            controller: _build,
            style: context.typography.body.copyWith(color: c.textPrimary),
            decoration: dropDecoration(context),
          ),
          SizedBox(height: context.spacing.xl2),
          const FieldLabel('Assign to (optional)'),
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
