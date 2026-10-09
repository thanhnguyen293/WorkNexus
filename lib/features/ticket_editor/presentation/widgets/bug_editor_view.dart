import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/navigation/ticket_editor_route.dart';
import '../../../../core/widgets/html_editing_controller.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/bug_editor_controller.dart';
import 'bug_main_fields.dart';
import 'bug_side_fields.dart';
import 'editor_columns.dart';
import 'editor_header.dart';

/// Adds or edits a bug, full screen; saving opens the saved bug.
class BugEditorView extends ConsumerStatefulWidget {
  const BugEditorView({super.key, required this.route});

  final TicketEditorRoute route;

  @override
  ConsumerState<BugEditorView> createState() => _BugEditorViewState();
}

class _BugEditorViewState extends ConsumerState<BugEditorView> {
  /// The steps' rich text, made once the bug has loaded.
  HtmlEditingController? _steps;

  @override
  void dispose() {
    _steps?.dispose();
    super.dispose();
  }

  void _close() => ref.read(ticketEditorProvider.notifier).close();

  Future<void> _save() async {
    final controller = ref.read(bugEditorProvider(widget.route).notifier);
    final steps = _steps;
    if (steps != null) controller.edit((d) => d.copyWith(steps: steps.html));
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
      EditBugRoute(:final bugId) => l.editBugTitle(bugId),
      _ => l.newBug,
    };
    final async = ref.watch(bugEditorProvider(route));
    final state = async.asData?.value;
    if (state != null)
      _steps ??= HtmlEditingController(html: state.draft.steps);
    final steps = _steps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorHeader(
          title: title,
          kind: 'bug',
          onClose: _close,
          onSave: state == null ? null : _save,
          saving: state?.saving ?? false,
          error: state?.failure?.message,
        ),
        Expanded(
          child: switch (async) {
            AsyncData() when state != null && steps != null => EditorColumns(
              main: BugMainFields(route: route, state: state, steps: steps),
              side: BugSideFields(route: route, state: state),
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
