import '../value_objects/notification_action.dart';

/// Who did what, read out of a notification's text.
typedef NotificationEvent = ({String actor, NotificationAction action});

/// Reads "who did what" out of ZenTao's notification text, so it can be
/// shown in the app's language whatever language ZenTao wrote it in.
///
/// ZenTao writes the text in the language of the request that caused it:
/// `JunNg assigned Bug` (English) or `Thanh指派了Bug` (Chinese) for the same
/// action. Null when the text holds no known action — it is then shown as
/// ZenTao wrote it.
class ParseNotificationEvent {
  const ParseNotificationEvent();

  /// ZenTao's action labels (`module/action/lang/{en,zh-cn}.php`): English
  /// words stand between spaces, Chinese ones follow the name directly.
  static const _labels = <NotificationAction, List<String>>{
    NotificationAction.created: ['created', '创建了'],
    NotificationAction.opened: ['opened'],
    NotificationAction.changed: ['changed', '变更了'],
    NotificationAction.edited: ['edited', '编辑了'],
    NotificationAction.assigned: ['assigned', '指派了'],
    NotificationAction.closed: ['closed', '关闭了'],
    NotificationAction.deleted: ['deleted', '删除了'],
    NotificationAction.commented: ['commented', '评论了'],
    NotificationAction.activated: ['activated', '激活了'],
    NotificationAction.resolved: ['resolved', '解决了'],
    NotificationAction.reviewed: ['reviewed', '评审了'],
    NotificationAction.confirmed: ['confirmed', '确认了'],
    NotificationAction.started: ['started', '开始了'],
    NotificationAction.restarted: ['restarted', '继续了'],
    NotificationAction.finished: ['finished', '完成了'],
    NotificationAction.paused: ['paused', '暂停了'],
    NotificationAction.canceled: ['cancelled', 'canceled', '取消了'],
  };

  static final _ascii = RegExp(r'^[a-z]+$');

  NotificationEvent? call(String text) {
    final summary = text.trim();
    ({int at, String actor, NotificationAction action})? first;
    for (final MapEntry(key: action, value: labels) in _labels.entries) {
      for (final label in labels) {
        final match = _ascii.hasMatch(label)
            ? RegExp('\\s$label\\s').firstMatch(summary)
            : RegExp(RegExp.escape(label)).firstMatch(summary);
        if (match == null) continue;
        final actor = summary.substring(0, match.start).trim();
        // An action needs someone doing it and something it was done to.
        if (actor.isEmpty || match.end >= summary.length) continue;
        if (first == null || match.start < first.at) {
          first = (at: match.start, actor: actor, action: action);
        }
      }
    }
    return first == null ? null : (actor: first.actor, action: first.action);
  }
}
