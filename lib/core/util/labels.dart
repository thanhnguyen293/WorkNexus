import '../../l10n/app_localizations.dart';
import '../domain/entities/provider_entity.dart';
import '../domain/entities/ticket.dart';
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

/// Prefixes of synthetic board-membership labels added at list-sync time (e.g.
/// `zentao-product:<id>` for bug boards, `gitlab-project:<id>` / `github-repo:`
/// for the Git provider boards) that the provider's detail endpoint doesn't
/// return. The native boards filter on these, so a detail refresh must keep
/// them — but they are internal machinery and must never be shown as tags.
const List<String> kSyntheticLabelPrefixes = <String>[
  'zentao-product:',
  'zentao-execution:',
  'gitlab-project:',
  'github-repo:',
];

/// The user-facing provider labels (real tags): drops the internal synthetic
/// board-membership labels ([kSyntheticLabelPrefixes]), the optimistic
/// `resolution:` marker, and the `priority::` scope (already shown as the
/// priority tag). Used by the board card and the detail panel.
List<String> visibleUserLabels(List<String> labels) => [
  for (final label in labels)
    if (!kSyntheticLabelPrefixes.any(label.startsWith) &&
        !label.toLowerCase().startsWith('resolution:') &&
        !label.toLowerCase().startsWith('priority::'))
      label,
];

/// The provider label colors carried on [t] — label name → `#RRGGBB` for the
/// chip `background` and `text`. Empty when the provider doesn't supply them
/// (only GitLab does today), so chips fall back to the neutral style.
({Map<String, String> background, Map<String, String> text}) labelColorsOf(
  Ticket t,
) => switch (t.providerEntity) {
  GitLabItemEntity(:final labelColors, :final labelTextColors) => (
    background: labelColors,
    text: labelTextColors,
  ),
  _ => (background: const {}, text: const {}),
};
