import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/zentao_dashboard.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/usecases/build_work_queue.dart';
import '../../domain/usecases/filter_my_work.dart';
import '../../domain/usecases/refresh_dashboard.dart';
import '../../domain/value_objects/dashboard_item_kind.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => getIt<DashboardRepository>(),
);

final refreshDashboardProvider = Provider<RefreshDashboard>(
  (ref) => getIt<RefreshDashboard>(),
);

/// The dashboard exists per connected ZenTao account.
final dashboardAccountsProvider = Provider<List<Account>>((ref) {
  final accounts = ref.watch(accountsProvider).asData?.value ?? const [];
  return [
    for (final a in accounts)
      if (a.providerType == ProviderType.zentao) a,
  ];
});

/// The account picked in the dashboard header (null = the first one).
final dashboardPickedAccountIdProvider = StateProvider<String?>((ref) => null);

/// The account whose dashboard is shown, or null without a ZenTao account.
final dashboardAccountProvider = Provider<Account?>((ref) {
  final accounts = ref.watch(dashboardAccountsProvider);
  final picked = ref.watch(dashboardPickedAccountIdProvider);
  return accounts.where((a) => a.id == picked).firstOrNull ??
      accounts.firstOrNull;
});

/// The stored dashboard of an account (null until first fetched), live.
final dashboardProvider = StreamProvider.autoDispose
    .family<ZenTaoDashboard?, String>(
      (ref, accountId) =>
          ref.watch(dashboardRepositoryProvider).watch(accountId),
    );

/// Fetch state of an account's dashboard: loading while a refresh runs, an
/// error ([DashboardRefreshException]) when the last one failed. Watching it
/// brings the stored dashboard up to date, unless it is still fresh.
final dashboardRefreshProvider = AsyncNotifierProvider.autoDispose
    .family<DashboardRefreshController, void, String>(
      DashboardRefreshController.new,
    );

class DashboardRefreshController extends AsyncNotifier<void> {
  DashboardRefreshController(this.accountId);

  final String accountId;

  @override
  Future<void> build() => _run(force: false);

  /// Fetches the dashboard again, even when the stored one is fresh.
  Future<void> refresh() async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _run(force: true));
  }

  Future<void> _run({required bool force}) async {
    final res = await ref
        .read(refreshDashboardProvider)
        .call(accountId, force: force);
    // AsyncValue carries the failure to the page as its error state.
    if (res case Err(:final failure)) throw DashboardRefreshException(failure);
  }
}

/// The error of [dashboardRefreshProvider]: why the last refresh failed.
class DashboardRefreshException implements Exception {
  const DashboardRefreshException(this.failure);

  final Failure failure;

  @override
  String toString() => failure.toString();
}

/// The "my work" list opened from a dashboard card (null = the overview).
final dashboardWorkKindProvider = StateProvider<DashboardItemKind?>(
  (ref) => null,
);

/// Which "my work" list: the account, its user, the kind and whether only
/// unfinished items count.
typedef MyWorkKey = ({
  String accountId,
  String user,
  DashboardItemKind kind,
  bool openOnly,
});

/// Every stored ticket of [MyWorkKey.kind] assigned to the account's user.
final myWorkProvider = Provider.autoDispose.family<List<Ticket>, MyWorkKey>(
  (ref, key) => const FilterMyWork()(
    ref.watch(ticketsProvider).asData?.value ?? const [],
    accountId: key.accountId,
    userAccount: key.user,
    kind: key.kind,
    openOnly: key.openOnly,
  ),
);

/// Whether the full "my work" list shows only unfinished items.
final dashboardWorkOpenOnlyProvider = StateProvider<bool>((ref) => true);

/// Sync state of an account's assigned work: watching it fetches every
/// assigned bug and task once; [MyWorkSyncController.refresh] does it again.
final myWorkSyncProvider = AsyncNotifierProvider.autoDispose
    .family<MyWorkSyncController, void, String>(MyWorkSyncController.new);

class MyWorkSyncController extends AsyncNotifier<void> {
  MyWorkSyncController(this.accountId);

  final String accountId;

  @override
  Future<void> build() => _run();

  Future<void> refresh() async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_run);
  }

  Future<void> _run() async {
    final res = await ref
        .read(dashboardRepositoryProvider)
        .syncAssignedWork(accountId);
    if (res case Err(:final failure)) throw DashboardRefreshException(failure);
  }
}

/// The user's open bugs and tasks as one queue (in progress, then not
/// started), plus how many of each are open.
final workQueueProvider = Provider.autoDispose
    .family<({WorkQueue queue, int openTasks, int openBugs}), Account>((
      ref,
      account,
    ) {
      List<Ticket> open(DashboardItemKind kind) => ref.watch(
        myWorkProvider((
          accountId: account.id,
          user: account.handle,
          kind: kind,
          openOnly: true,
        )),
      );
      final tasks = open(DashboardItemKind.task);
      final bugs = open(DashboardItemKind.bug);
      return (
        queue: const BuildWorkQueue()([...bugs, ...tasks]),
        openTasks: tasks.length,
        openBugs: bugs.length,
      );
    });
