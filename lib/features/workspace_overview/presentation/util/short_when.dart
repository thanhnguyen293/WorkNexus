export '../../../../core/util/relative_time.dart' show shortWhen;

/// A ZenTao date field (`2026-10-12`), or null for its empty forms
/// (`''`, `0000-00-00`). Normalized to UTC.
DateTime? parseZenTaoDate(String? raw) {
  final d = DateTime.tryParse(raw?.trim() ?? '');
  return d == null || d.year < 2000 ? null : d.toUtc();
}
