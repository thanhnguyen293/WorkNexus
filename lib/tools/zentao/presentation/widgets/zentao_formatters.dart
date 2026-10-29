import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../domain/usecases/is_due_this_week.dart';

/// Formatter and extraction utilities for ZenTao tickets and bugs.
abstract final class ZenTaoFormatters {
  /// Extracts the target deadline from ticket metadata, labels, or bug entity.
  static DateTime? extractDeadline(Ticket ticket) =>
      extractZenTaoDeadline(ticket);

  /// Calculates delay string (e.g. "Delay 45 days") if the deadline has passed.
  /// ZenTao deadlines are calendar dates (end-of-day), so a task due today
  /// is not delayed; it only becomes delayed on subsequent calendar days.
  static String? calcDelayText(
    DateTime? deadline, {
    UnifiedStatus? status,
    DateTime? now,
  }) {
    if (deadline == null) return null;
    if (status == UnifiedStatus.done) return null;
    final current = (now ?? DateTime.now()).toLocal();
    final target = deadline.toLocal();

    final todayUtc = DateTime.utc(current.year, current.month, current.day);
    final deadlineUtc = DateTime.utc(target.year, target.month, target.day);

    final diff = todayUtc.difference(deadlineUtc).inDays;
    if (diff <= 0) return null;
    return 'Delay $diff ${diff == 1 ? "day" : "days"}';
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

  /// Formats date to YYYY-MM-DD.
  static String formatDeadline(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
