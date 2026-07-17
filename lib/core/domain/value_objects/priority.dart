/// Unified priority. `level` 0..3 maps urgent→low, matching the design's
/// `PRIO_VAR` ordering. Provider-specific labels (e.g. GitHub `P0`, Jira
/// `Highest`) are rendered in the presentation layer, not here.
enum Priority {
  urgent(level: 0),
  high(level: 1),
  medium(level: 2),
  low(level: 3);

  const Priority({required this.level});

  final int level;

  static Priority fromLevel(int level) {
    final clamped = level.clamp(0, 3);
    return Priority.values.firstWhere((p) => p.level == clamped);
  }
}
