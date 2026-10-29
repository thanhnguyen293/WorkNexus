import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/navigation/ticket_editor_route.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../core/widgets/html_editing_controller.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../providers/bug_editor_controller.dart';
import 'bug_main_fields.dart';
import 'bug_side_fields.dart';
import 'confirm_discard_draft.dart';
import 'draft_picker_button.dart';
import 'editor_columns.dart';
import 'editor_header.dart';
import 'editor_shortcuts.dart';
import 'rich_text_draft_sync.dart';

/// Adds or edits a bug, full screen; saving opens the saved bug.
class BugEditorView extends ConsumerStatefulWidget {
  const BugEditorView({super.key, required this.route});

  final TicketEditorRoute route;

  @override
  ConsumerState<BugEditorView> createState() => _BugEditorViewState();
}

class _BugEditorViewState extends ConsumerState<BugEditorView>
    with RichTextDraftSync {
  /// The steps' rich text, made once the bug has loaded.
  HtmlEditingController? _steps;

  @override
  void dispose() {
    stopRichTextSync();
    _steps?.dispose();
    super.dispose();
  }

  HtmlEditingController _startSteps(String html) {
    final text = HtmlEditingController(html: html);
    syncRichText(text, (html) {
      final provider = bugEditorProvider(widget.route);
      if (ref.read(provider).asData?.value.draft.steps == html) return;
      ref.read(provider.notifier).edit((d) => d.copyWith(steps: html));
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
    final controller = ref.read(bugEditorProvider(widget.route).notifier);
    // Not deleted: the editor stays open, the header saying why.
    if (!await controller.discardDraft() || !mounted) return;
    stopRichTextSync();
    ref.read(appNavProvider.notifier).closeEditor();
  }

  Future<void> _save() async {
    final controller = ref.read(bugEditorProvider(widget.route).notifier);
    pushRichText();
    final messenger = ScaffoldMessenger.of(context);
    final saved = AppL10n.of(context).formSaved;
    final ticketId = await controller.save();
    if (ticketId == null || !mounted) return;
    _close();
    ref.read(boardRefreshTriggerProvider.notifier).trigger();
    ref.read(appNavProvider.notifier).openTicket(ticketId);
    showAppSnackOn(messenger, saved);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final route = widget.route;
    final title = switch (route) {
      EditBugRoute(:final bugId) => l.editBugTitle(bugId),
      _ => l.newBug,
    };
    final async = ref.watch(bugEditorProvider(route));
    final state = async.asData?.value;
    if (state != null) {
      _steps ??= _startSteps(state.draft.steps);
    }
    final steps = _steps;
    final save = state == null || state.saving ? null : _save;
    return EditorShortcuts(
      onClose: _close,
      onSave: save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EditorHeader(
            title: title,
            kind: 'bug',
            onClose: _close,
            onSave: state == null ? null : _save,
            saving: state?.saving ?? false,
            error: state?.failure?.message,
            draftSaved: state?.draftSavedAt != null,
            draftPicker: switch (route) {
              NewBugRoute(:final accountId, :final draftId) =>
                DraftPickerButton(
                  isBug: true,
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
              AsyncData() when state != null && steps != null => EditorColumns(
                main: BugMainFields(route: route, state: state, steps: steps),
                side: BugSideFields(route: route, state: state),
              ),
              AsyncError() => AppStateView.error(
                title: l.formLoadFailed,
                onRetry: () => ref.invalidate(bugEditorProvider(route)),
              ),
              _ => const AppStateView.loading(),
            },
          ),
        ],
      ),
    );
  }
}
