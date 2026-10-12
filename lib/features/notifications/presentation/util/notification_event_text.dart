import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/zentao_notification.dart';
import '../../domain/usecases/parse_notification_event.dart';

/// [n]'s "who did what" in the app's language ("JunNg đã giao Bug"), whatever
/// language ZenTao wrote it in; ZenTao's own text when it names no known
/// action or object.
String notificationEventText(AppL10n l, ZenTaoNotification n) {
  final event = const ParseNotificationEvent()(n.summary);
  final object = switch (n.objectType) {
    'bug' => l.bugTag,
    'task' => l.taskTag,
    'story' => l.storyTag,
    _ => null,
  };
  if (event == null || object == null) return n.summary;
  return l.notificationEvent(
    event.actor,
    l.notificationAction(event.action.name),
    object,
  );
}
