import '../entities/zentao_notification.dart';

/// One calendar day of notifications; [day] is null for undated ones.
typedef NotificationDay = ({DateTime? day, List<ZenTaoNotification> items});

/// Groups notifications by local calendar day, newest day (and newest item)
/// first, like ZenTao's bell menu. With [unreadOnly], read ones are left out.
class GroupNotificationsByDay {
  const GroupNotificationsByDay();

  List<NotificationDay> call(
    Iterable<ZenTaoNotification> notifications, {
    bool unreadOnly = false,
  }) {
    final sorted = notifications.where((n) => !unreadOnly || !n.read).toList()
      ..sort(
        (a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
      );
    final days = <NotificationDay>[];
    for (final n in sorted) {
      final at = n.createdAt?.toLocal();
      final day = at == null ? null : DateTime(at.year, at.month, at.day);
      if (days.isNotEmpty && days.last.day == day) {
        days.last.items.add(n);
      } else {
        days.add((day: day, items: [n]));
      }
    }
    return days;
  }
}
