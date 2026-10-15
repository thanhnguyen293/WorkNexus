import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';

/// Extracts the target deadline from ticket metadata, labels, or task/bug entity.
DateTime? extractZenTaoDeadline(Ticket ticket) {
  final pe = ticket.providerEntity;
  if (pe is ZenTaoBugEntity && pe.deadline != null && pe.deadline!.isNotEmpty) {
    return DateTime.tryParse(pe.deadline!);
  }
  if (pe is ZenTaoTaskEntity &&
      pe.deadline != null &&
      pe.deadline!.isNotEmpty) {
    return DateTime.tryParse(pe.deadline!);
  }
  for (final l in ticket.labels) {
    if (l.startsWith('deadline:')) {
      return DateTime.tryParse(l.substring(9));
    }
  }
  return null;
}

/// Determines whether a [DateTime] deadline falls within the current ISO-8601 week
/// (Monday 00:00:00 to Sunday 23:59:59.999) in the local time zone.
class IsDueThisWeek {
  const IsDueThisWeek();

  bool call(DateTime dateTime, {DateTime? now}) {
    final current = (now ?? DateTime.now()).toLocal();
    final target = dateTime.toLocal();

    final monday = DateTime(
      current.year,
      current.month,
      current.day - (current.weekday - 1),
    );
    final sundayEnd = DateTime(
      current.year,
      current.month,
      current.day + (7 - current.weekday),
      23,
      59,
      59,
      999,
    );

    return !target.isBefore(monday) && !target.isAfter(sundayEnd);
  }
}
