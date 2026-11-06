import '../../../../core/domain/entities/ticket.dart';
import '../../domain/usecases/is_due_this_week.dart';

/// Formatter and extraction utilities for ZenTao tickets and bugs.
abstract final class ZenTaoFormatters {
  /// Extracts the target deadline from ticket metadata, labels, or bug entity.
  static DateTime? extractDeadline(Ticket ticket) =>
      extractZenTaoDeadline(ticket);

  /// Calculates delay string (e.g. "Delay 45 days") if the deadline has passed.
  static String? calcDelayText(DateTime? deadline) {
    if (deadline == null) return null;
    final now = DateTime.now();
    if (!deadline.isBefore(now)) return null;
    final diff = now.difference(deadline).inDays;
    final days = diff <= 0 ? 1 : diff;
    return 'Delay $days ${days == 1 ? "day" : "days"}';
  }

  /// Splits "[Module] Title" into clean title and module tag.
  static (String, String?) extractModule(String rawTitle) {
    final match = RegExp(
      r'^(\[[^\]]+(?:\]\[[^\]]+)*\])\s*(.*)$',
    ).firstMatch(rawTitle);
    if (match != null) {
      return (match.group(2)!.trim(), match.group(1));
    }
    return (rawTitle, null);
  }

  /// Splits "[Discovery][Change Request] Title" (or "[Mobile] [SocialFi]
  /// Title", tags apart) into the title and its leading bracketed tags,
  /// without the brackets. A title that is nothing but tags keeps them.
  static (String, List<String>) extractTags(String rawTitle) {
    final tags = <String>[];
    var rest = rawTitle.trim();
    final lead = RegExp(r'^\[([^\]]*)\]\s*');
    for (var m = lead.firstMatch(rest); m != null; m = lead.firstMatch(rest)) {
      final tag = m.group(1)?.trim() ?? '';
      if (tag.isNotEmpty) tags.add(tag);
      rest = rest.substring(m.end);
    }
    if (rest.isEmpty) return (rawTitle.trim(), const []);
    return (rest, tags);
  }

  /// Formats date to YYYY-MM-DD.
  static String formatDeadline(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
