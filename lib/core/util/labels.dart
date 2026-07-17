import '../../l10n/app_localizations.dart';
import '../domain/value_objects/priority.dart';
import '../domain/value_objects/unified_status.dart';

/// Localized label for a [UnifiedStatus] (board column / status chip).
///
/// Shared across features (board, task_detail) — lives in `core/` per the
/// feature-isolation rule (10.3) so no feature reaches into another for it.
String statusLabel(AppL10n l, UnifiedStatus s) => switch (s) {
  UnifiedStatus.inbox => l.colInbox,
  UnifiedStatus.todo => l.colTodo,
  UnifiedStatus.inprogress => l.colInprogress,
  UnifiedStatus.review => l.colReview,
  UnifiedStatus.blocked => l.colBlocked,
  UnifiedStatus.done => l.colDone,
};

/// Localized label for a [Priority].
String priorityName(AppL10n l, Priority p) => switch (p) {
  Priority.urgent => l.priorityUrgent,
  Priority.high => l.priorityHigh,
  Priority.medium => l.priorityMedium,
  Priority.low => l.priorityLow,
};
