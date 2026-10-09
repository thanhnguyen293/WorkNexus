import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/zentao_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/usecases/group_notifications_by_day.dart';
import '../../domain/usecases/refresh_notifications.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => getIt<NotificationRepository>(),
);

final refreshNotificationsProvider = Provider<RefreshNotifications>(
  (ref) => getIt<RefreshNotifications>(),
);

/// Notifications exist per connected ZenTao account.
final notificationAccountsProvider = Provider<List<Account>>((ref) {
  final accounts = ref.watch(accountsProvider).asData?.value ?? const [];
  return [
    for (final a in accounts)
      if (a.providerType == ProviderType.zentao) a,
  ];
});

/// Every stored notification of every ZenTao account, newest first.
final notificationsProvider = StreamProvider<List<ZenTaoNotification>>(
  (ref) => ref.watch(notificationRepositoryProvider).watchAll(),
);

final unreadNotificationCountProvider = Provider<int>(
  (ref) =>
      ref
          .watch(notificationsProvider)
          .asData
          ?.value
          .where((n) => !n.read)
          .length ??
      0,
);

/// The page's tab: true = unread only (ZenTao's default), false = all.
final notificationsUnreadOnlyProvider = StateProvider<bool>((ref) => true);

/// The notifications shown on the page, grouped by day.
final notificationDaysProvider = Provider<List<NotificationDay>>((ref) {
  final all = ref.watch(notificationsProvider).asData?.value ?? const [];
  return const GroupNotificationsByDay()(
    all,
    unreadOnly: ref.watch(notificationsUnreadOnlyProvider),
  );
});

/// Fetch state of the notifications of every ZenTao account: loading while a
/// refresh runs, an error ([NotificationsException]) when the last one failed.
/// Watching it fetches once, then again every [_pollEvery] so the rail badge
/// stays current (ZenTao's own bell polls too).
final notificationsRefreshProvider =
    AsyncNotifierProvider<NotificationsRefreshController, void>(
      NotificationsRefreshController.new,
    );

class NotificationsRefreshController extends AsyncNotifier<void> {
  static const _pollEvery = Duration(minutes: 2);

  @override
  Future<void> build() async {
    final ids = [for (final a in ref.watch(notificationAccountsProvider)) a.id];
    if (ids.isEmpty) return;
    final timer = Timer.periodic(_pollEvery, (_) => refresh());
    ref.onDispose(timer.cancel);
    await _run(ids);
  }

  Future<void> refresh() async {
    if (state.isLoading) return;
    final ids = [for (final a in ref.read(notificationAccountsProvider)) a.id];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _run(ids));
  }

  Future<void> _run(List<String> ids) async {
    final res = await ref.read(refreshNotificationsProvider).call(ids);
    // AsyncValue carries the failure to the page as its error state.
    if (res case Err(:final failure)) throw NotificationsException(failure);
  }
}

/// A notification refresh or command that failed.
class NotificationsException implements Exception {
  const NotificationsException(this.failure);

  final Failure failure;

  @override
  String toString() => failure.toString();
}
