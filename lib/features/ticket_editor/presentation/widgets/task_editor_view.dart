import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/navigation/ticket_editor_route.dart';
import '../../../../core/widgets/html_editing_controller.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/task_editor_controller.dart';
import 'editor_columns.dart';
import 'editor_header.dart';
import 'task_main_fields.dart';
import 'task_side_fields.dart';

/// Adds or edits a task, full screen; saving opens the saved task.
class TaskEditorView extends ConsumerStatefulWidget {
  const TaskEditorView({super.key, required this.route});

  final TicketEditorRoute route;

  @override
  ConsumerState<TaskEditorView> createState() => _TaskEditorViewState();
}

class _TaskEditorViewState extends ConsumerState<TaskEditorView> {
  /// The description's rich text, made once the task has loaded.
  HtmlEditingController? _desc;

  @override
  void dispose() {
    _desc?.dispose();
    super.dispose();
  }

  void _close() => ref.read(ticketEditorProvider.notifier).close();

  Future<void> _save() async {
    final controller = ref.read(taskEditorProvider(widget.route).notifier);
    final desc = _desc;
    if (desc != null) controller.edit((d) => d.copyWith(desc: desc.html));
    final messenger = ScaffoldMessenger.of(context);
    final saved = AppL10n.of(context).formSaved;
    final ticketId = await controller.save();
    if (ticketId == null || !mounted) return;
    _close();
    ref.read(openTicketIdProvider.notifier).open(ticketId);
    messenger.showSnackBar(SnackBar(content: Text(saved)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final route = widget.route;
    final title = switch (route) {
      EditTaskRoute(:final taskId) => l.editTaskTitle(taskId),
      _ => l.newTask,
    };
    final async = ref.watch(taskEditorProvider(route));
    final state = async.asData?.value;
    if (state != null) _desc ??= HtmlEditingController(html: state.draft.desc);
    final desc = _desc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorHeader(
          title: title,
          kind: 'task',
          onClose: _close,
          onSave: state == null ? null : _save,
          saving: state?.saving ?? false,
          error: state?.failure?.message,
        ),
        Expanded(
          child: switch (async) {
            AsyncData() when state != null && desc != null => EditorColumns(
              main: TaskMainFields(route: route, state: state, desc: desc),
              side: TaskSideFields(route: route, state: state),
            ),
            AsyncError(:final error) => Center(
              child: AppInlineNote(
                text: '${l.formLoadFailed}: $error',
                isError: true,
              ),
            ),
            _ => const AppInlineSpinner(),
          },
        ),
      ],
    );
  }
}
