import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/platform/desktop_window_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/zentao_notification.dart';
import '../../domain/usecases/find_new_notifications.dart';
import '../providers/notification_providers.dart';
import '../util/notification_actions.dart';
import '../util/notification_event_text.dart';

/// Raises a desktop notification for each ZenTao notification a refresh (the
/// two-minute poll) brings in, unless the user is looking at the list itself.
/// More than a few at once are one notification counting them. Clicking one
/// brings the window up and opens what it links to, as its card does.
/// Wraps the app shell so it works whichever view is open.
class NotificationAlerts extends ConsumerStatefulWidget {
  const NotificationAlerts({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationAlerts> createState() => _NotificationAlertsState();
}

class _NotificationAlertsState extends ConsumerState<NotificationAlerts> {
  /// Above this many at once, one notification counts them instead.
  static const _maxEach = 3;

  /// The id of the counting notification; each refresh replaces it.
  static const _countId = 0x2e40;

  Set<String>? _seen;
  StreamSubscription<String>? _taps;

  @override
  void initState() {
    super.initState();
    _taps = ref.read(notificationDesktopNotifierProvider).taps.listen(_onTap);
    ref.listenManual<AsyncValue<List<ZenTaoNotification>>>(
      notificationsProvider,
      (_, next) {
        if (next.value case final list?) unawaited(_onList(list));
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _taps?.cancel();
    super.dispose();
  }

  Future<void> _onList(List<ZenTaoNotification> list) async {
    final found = const FindNewNotifications()((seen: _seen, current: list));
    _seen = found.seen;
    final fresh = found.fresh;
    if (fresh.isEmpty) return;
    final focused = await const DesktopWindowService().isFocused();
    if (!mounted) return;
    if (focused && ref.read(notificationsPanelOpenProvider)) return;
    final l = AppL10n.of(context);
    final notifier = ref.read(notificationDesktopNotifierProvider);
    if (fresh.length > _maxEach) {
      await notifier.show(
        id: _countId,
        title: l.notificationsNewCount(fresh.length),
        body: notificationEventText(l, fresh.first),
        payload: jsonEncode({'zn': null}),
      );
      return;
    }
    for (final n in fresh) {
      await notifier.show(
        id: FindNewNotifications.keyOf(n).hashCode & 0x7fffffff,
        title: notificationEventText(l, n),
        body: [if (n.objectId case final id?) '#$id', ?n.objectTitle].join(' '),
        payload: jsonEncode({'zn': n.id, 'a': n.accountId}),
      );
    }
  }

  /// A notification of ours opens what it links to; the counting one (or one
  /// no longer listed) opens the list.
  Future<void> _onTap(String payload) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException {
      return;
    }
    if (decoded is! Map || !decoded.containsKey('zn')) return;
    final id = decoded['zn'];
    final accountId = decoded['a'];
    await const DesktopWindowService().bringToFront();
    if (!mounted) return;
    final list = ref.read(notificationsProvider).value ?? const [];
    final tapped = list
        .where((n) => n.id == id && n.accountId == accountId)
        .firstOrNull;
    if (tapped != null) {
      await openNotification(context, ref, tapped);
      return;
    }
    if (!ref.read(notificationsPanelOpenProvider)) {
      ref.read(appNavProvider.notifier).toggleNotifications();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
