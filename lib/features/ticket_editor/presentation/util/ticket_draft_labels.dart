import 'package:flutter/widgets.dart';

import '../../../../core/navigation/ticket_editor_route.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/util/relative_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/saved_ticket_draft.dart';

/// The editor route that picks [draft] up again.
TicketEditorRoute draftRoute(SavedTicketDraft draft) => switch (draft) {
  SavedBugDraft(:final accountId, :final id, draft: final bug) => NewBugRoute(
    accountId: accountId,
    productId: bug.product,
    draftId: id,
  ),
  SavedTaskDraft(:final accountId, :final id, draft: final task) =>
    NewTaskRoute(
      accountId: accountId,
      executionId: task.execution,
      draftId: id,
    ),
};

/// Longest draft title a menu shows whole, so a long one does not stretch the
/// menu across the window.
const _titleLength = 40;

/// [draft] as a menu row names it: its title (shortened) and when it was last
/// changed, telling apart drafts not yet titled.
String draftLabel(
  BuildContext context,
  SavedTicketDraft draft, {
  required DateDisplayFormat dateFormat,
}) {
  final l = AppL10n.of(context);
  final title = draft.title.trim();
  return l.ticketDraftLabel(
    title.isEmpty
        ? l.ticketDraftUntitled
        : title.length <= _titleLength
        ? title
        : '${title.substring(0, _titleLength).trimRight()}…',
    formatWhen(context, draft.updatedAt, format: dateFormat),
  );
}
