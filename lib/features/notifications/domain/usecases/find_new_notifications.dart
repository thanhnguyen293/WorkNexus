import '../../../../core/usecase/usecase.dart';
import '../entities/zentao_notification.dart';

/// What [FindNewNotifications] reports: the unread notifications that were not
/// there before ([fresh], newest first) and every notification there now
/// ([seen]), to compare the next list with.
typedef NewNotifications = ({List<ZenTaoNotification> fresh, Set<String> seen});

/// Input for [FindNewNotifications]: the notifications already [seen] (null
/// before the first list) and the [current] list.
typedef NewNotificationsInput = ({
  Set<String>? seen,
  List<ZenTaoNotification> current,
});

/// The unread notifications a refresh brought in, to raise on the desktop. The
/// first list is the backlog, not news: it only becomes what has been seen.
/// A notification read elsewhere before it was seen here is not raised.
class FindNewNotifications
    extends UseCase<NewNotifications, NewNotificationsInput> {
  const FindNewNotifications();

  /// One notification's key across accounts.
  static String keyOf(ZenTaoNotification n) => '${n.accountId}:${n.id}';

  @override
  NewNotifications call(NewNotificationsInput input) {
    final seen = {for (final n in input.current) keyOf(n)};
    final before = input.seen;
    if (before == null) return (fresh: const [], seen: seen);
    final fresh = [
      for (final n in input.current)
        if (!n.read && !before.contains(keyOf(n))) n,
    ]..sort((a, b) => _time(b).compareTo(_time(a)));
    // Kept once seen: a notification that drops off the list and comes back
    // (a refresh that briefly failed) is not news either.
    return (fresh: fresh, seen: {...before, ...seen});
  }

  static DateTime _time(ZenTaoNotification n) =>
      n.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
}
