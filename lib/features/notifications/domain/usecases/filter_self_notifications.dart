import '../../../../core/domain/entities/account.dart';
import '../entities/zentao_notification.dart';
import 'parse_notification_event.dart';

/// Filters out notifications where the action was initiated by the current user
/// (e.g. self-starting a task, editing, closing, or resolving). Only notifications
/// for actions performed by other people related to the user are kept.
class FilterSelfNotifications {
  const FilterSelfNotifications();

  List<ZenTaoNotification> call(
    List<ZenTaoNotification> notifications, {
    required List<Account> accounts,
    Map<String, String>? realnamesByAccountId,
  }) {
    if (notifications.isEmpty || accounts.isEmpty) return notifications;

    final candidatesByAccount = <String, Set<String>>{};
    final allCandidates = <String>{};

    for (final account in accounts) {
      final names = <String>{};
      final handle = account.handle.trim();
      if (handle.isNotEmpty) names.add(handle.toLowerCase());

      final realname = realnamesByAccountId?[account.id]?.trim();
      if (realname != null && realname.isNotEmpty) {
        names.add(realname.toLowerCase());
      }

      candidatesByAccount[account.id] = names;
      allCandidates.addAll(names);
    }

    if (allCandidates.isEmpty) return notifications;

    const parser = ParseNotificationEvent();

    return [
      for (final n in notifications)
        if (!_isSelf(
          n,
          parser: parser,
          accountCandidates: candidatesByAccount[n.accountId] ?? allCandidates,
        ))
          n,
    ];
  }

  bool _isSelf(
    ZenTaoNotification n, {
    required ParseNotificationEvent parser,
    required Set<String> accountCandidates,
  }) {
    final summary = n.summary.trim();
    if (summary.isEmpty) return false;

    final event = parser(summary);
    if (event != null) {
      final actor = event.actor.trim().toLowerCase();
      if (accountCandidates.contains(actor)) return true;
    }

    // Fallback if parser didn't match a known verb: check if summary starts with candidate
    final lower = summary.toLowerCase();
    for (final candidate in accountCandidates) {
      if (candidate.isEmpty) continue;
      if (lower.startsWith(candidate)) {
        if (lower.length == candidate.length) return true;
        final nextChar = lower.substring(
          candidate.length,
          candidate.length + 1,
        );
        if (RegExp(r'^\s|[^\w]').hasMatch(nextChar) ||
            nextChar.codeUnitAt(0) > 127) {
          return true;
        }
      }
    }

    return false;
  }
}
