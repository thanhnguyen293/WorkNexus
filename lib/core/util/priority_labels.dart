import '../domain/entities/ticket.dart';
import '../domain/value_objects/priority.dart';
import '../domain/value_objects/provider_type.dart';

/// Priority detection from provider labels.
///
/// GitLab and GitHub have **no native priority** — it is inferred from a
/// `priority::<level>` (GitLab) or `priority: <level>` / `P1`-style (GitHub)
/// label. The normalizers fall back to [Priority.medium] so the board always has
/// a value to sort/filter by, but that fallback must not be shown as a *tag* —
/// otherwise every unlabelled issue and merge/pull request displays a fabricated
/// `priority::3` / `P2`. These detectors return `null` when no priority label is
/// present, so both the normalizer (which applies the fallback) and the UI
/// (which shows a tag only for a real priority) share one source of truth.

/// The GitLab priority in a scoped `priority::<level>` label, or `null` if none.
Priority? gitLabPriorityFromLabels(List<String> labels) {
  for (final raw in labels) {
    final l = raw.toLowerCase().trim();
    if (!l.startsWith('priority::')) continue;
    switch (l.substring('priority::'.length).trim()) {
      case 'urgent':
      case 'critical':
      case '1':
        return Priority.urgent;
      case 'high':
      case '2':
        return Priority.high;
      case 'medium':
      case 'normal':
      case '3':
        return Priority.medium;
      case 'low':
      case '4':
        return Priority.low;
    }
  }
  return null;
}

/// The GitHub priority in a `priority: <level>` / `P1`-style label, or `null`.
Priority? gitHubPriorityFromLabels(List<String> labels) {
  for (final raw in labels) {
    final l = raw.toLowerCase().trim();
    final v = l.startsWith('priority')
        ? l.replaceFirst(RegExp(r'^priority\s*[:/]?\s*'), '')
        : l;
    switch (v) {
      case 'urgent':
      case 'critical':
      case 'p0':
      case 'p1':
      case '1':
        return Priority.urgent;
      case 'high':
      case 'p2':
      case '2':
        return Priority.high;
      case 'medium':
      case 'normal':
      case 'p3':
      case '3':
        return Priority.medium;
      case 'low':
      case 'p4':
      case '4':
        return Priority.low;
    }
  }
  return null;
}

/// Whether [t] carries a *real* priority worth rendering as a tag.
///
/// ZenTao and Jira have a native priority field, so it is always meaningful.
/// GitLab/GitHub only do when a priority label is present — without one, their
/// priority is the normalizer's medium fallback, which should stay invisible.
bool hasExplicitPriority(Ticket t) => switch (t.providerType) {
  ProviderType.zentao || ProviderType.jira => true,
  ProviderType.gitlab => gitLabPriorityFromLabels(t.labels) != null,
  ProviderType.github => gitHubPriorityFromLabels(t.labels) != null,
};
