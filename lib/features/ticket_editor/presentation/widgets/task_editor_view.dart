import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/navigation/ticket_editor_route.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../core/widgets/html_editing_controller.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../providers/task_editor_controller.dart';
import 'confirm_discard_draft.dart';
import 'draft_picker_button.dart';
import 'editor_header.dart';
import 'editor_shortcuts.dart';
import 'rich_text_draft_sync.dart';
import 'task_form_centered.dart';
import 'task_form_fields.dart';

/// Adds or edits a task, full screen; saving opens the saved task.
class TaskEditorView extends ConsumerStatefulWidget {
  const TaskEditorView({super.key, required this.route});

  final TicketEditorRoute route;

  @override
  ConsumerState<TaskEditorView> createState() => _TaskEditorViewState();
}

class _TaskEditorViewState extends ConsumerState<TaskEditorView>
    with RichTextDraftSync {
  /// The description's rich text, made once the task has loaded.
  HtmlEditingController? _desc;

  @override
  void dispose() {
    stopRichTextSync();
    _desc?.dispose();
    super.dispose();
  }

  HtmlEditingController _startDesc(String html) {
    final text = HtmlEditingController(html: html);
    syncRichText(text, (html) {
      final provider = taskEditorProvider(widget.route);
      if (ref.read(provider).asData?.value.draft.desc == html) return;
      ref.read(provider.notifier).edit((d) => d.copyWith(desc: html));
    });
    return text;
  }

  void _close() {
    // The draft keeps what was typed last.
    pushRichText();
    ref.read(appNavProvider.notifier).closeEditor();
  }

  /// Switches to another kept draft; this one keeps what was typed last.
  void _openDraft(TicketEditorRoute route) {
    pushRichText();
    ref.read(appNavProvider.notifier).openEditor(route);
  }

  Future<void> _discardDraft() async {
    if (!await confirmDiscardDraft(context) || !mounted) return;
    final controller = ref.read(taskEditorProvider(widget.route).notifier);
    // Not deleted: the editor stays open, the header saying why.
    if (!await controller.discardDraft() || !mounted) return;
    stopRichTextSync();
    ref.read(appNavProvider.notifier).closeEditor();
  }

  /// Where saving a new task goes next (the form's "After saving" choice);
  /// by default the saved task, as before the form offered the choice.
  TaskAfterSave _next = TaskAfterSave.openTask;

  /// Bumped for each fresh form in this view, so its inputs start over.
  int _form = 0;

  /// Saves, then goes where [_next] says.
  Future<void> _save() async {
    final next = _next;
    final provider = taskEditorProvider(widget.route);
    final controller = ref.read(provider.notifier);
    final execution = ref.read(provider).asData?.value.draft.execution;
    pushRichText();
    final messenger = ScaffoldMessenger.of(context);
    final saved = AppL10n.of(context).formSaved;
    final ticketId = await controller.save();
    if (ticketId == null || !mounted) return;
    _close();
    ref.read(boardRefreshTriggerProvider.notifier).trigger();
    final nav = ref.read(appNavProvider.notifier);
    switch (next) {
      case TaskAfterSave.openTask:
        nav.openTicket(ticketId);
      case TaskAfterSave.continueAdding:
        final again = NewTaskRoute(
          accountId: widget.route.accountId,
          executionId: execution ?? '0',
        );
        nav.openEditor(again);
        // The same route as the form just saved keeps this view (and its
        // provider) alive: start both over empty, description included.
        ref.invalidate(taskEditorProvider(again));
        stopRichTextSync();
        _desc?.dispose();
        setState(() {
          _desc = null;
          _form++;
        });
      case TaskAfterSave.backToList:
        break;
    }
    showAppSnackOn(messenger, saved);
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
    if (state != null) _desc ??= _startDesc(state.draft.desc);
    final desc = _desc;
    final save = state == null || state.saving ? null : _save;
    return EditorShortcuts(
      onClose: _close,
      onSave: save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EditorHeader(
            title: title,
            kind: 'task',
            onClose: _close,
            onSave: state == null ? null : _save,
            saving: state?.saving ?? false,
            error: state?.failure?.message,
            draftSaved: state?.draftSavedAt != null,
            draftPicker: switch (route) {
              NewTaskRoute(:final accountId, :final draftId) =>
                DraftPickerButton(
                  isBug: false,
                  accountId: accountId,
                  currentDraftId: state?.draftId ?? draftId,
                  onPick: _openDraft,
                ),
              _ => null,
            },
            onDiscardDraft: state?.draftSavedAt == null ? null : _discardDraft,
          ),
          Expanded(
            child: switch (async) {
              AsyncData() when state != null && desc != null =>
                TaskFormCentered(
                  key: ValueKey(_form),
                  route: route,
                  state: state,
                  desc: desc,
                  onSave: _save,
                  next: _next,
                  onNextChanged: (v) => setState(() => _next = v),
                  onClose: _close,
                  saving: state.saving,
                ),
              AsyncError() => AppStateView.error(
                title: l.formLoadFailed,
                onRetry: () => ref.invalidate(taskEditorProvider(route)),
              ),
              _ => const AppStateView.loading(),
            },
          ),
        ],
      ),
    );
  }
}
