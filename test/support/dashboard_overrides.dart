import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/workspace_overview/domain/entities/dashboard_profile.dart';
import 'package:work_nexus/features/workspace_overview/domain/entities/zentao_dashboard.dart';
import 'package:work_nexus/features/workspace_overview/domain/repositories/dashboard_repository.dart';
import 'package:work_nexus/features/workspace_overview/domain/usecases/refresh_dashboard.dart';
import 'package:work_nexus/features/workspace_overview/presentation/providers/dashboard_providers.dart';

/// A dashboard store holding [stored] per account. A fetch stores an empty
/// dashboard for an account without one, like the server answering; the
/// calls are counted.
class FakeDashboardRepository implements DashboardRepository {
  FakeDashboardRepository([Map<String, ZenTaoDashboard> stored = const {}])
    : _stored = {...stored};

  final Map<String, ZenTaoDashboard> _stored;
  final _changes = StreamController<String>.broadcast();
  int refreshCalls = 0;
  int syncCalls = 0;

  @override
  Stream<ZenTaoDashboard?> watch(String accountId) {
    late final StreamController<ZenTaoDashboard?> out;
    StreamSubscription<String>? changes;
    out = StreamController(
      onListen: () {
        out.add(_stored[accountId]);
        changes = _changes.stream.listen((id) {
          if (id == accountId) out.add(_stored[accountId]);
        });
      },
      onCancel: () => changes?.cancel(),
    );
    return out.stream;
  }

  @override
  Future<ZenTaoDashboard?> cached(String accountId) async => _stored[accountId];

  @override
  Future<Result<void>> refresh(String accountId) async {
    refreshCalls++;
    _stored[accountId] ??= ZenTaoDashboard(
      accountId: accountId,
      profile: const DashboardProfile(account: 'me', realname: 'Me'),
      fetchedAt: DateTime.now(),
    );
    _changes.add(accountId);
    return const Ok(null);
  }

  @override
  Future<Result<void>> syncAssignedWork(String accountId) async {
    syncCalls++;
    return const Ok(null);
  }
}

/// The Overview shows a ZenTao account's dashboard: a test that pumps it
/// with one gets [repository] (an empty store by default) instead of the DI
/// registrations.
List<Override> dashboardOverrides({DashboardRepository? repository}) {
  final repo = repository ?? FakeDashboardRepository();
  return [
    dashboardRepositoryProvider.overrideWithValue(repo),
    refreshDashboardProvider.overrideWithValue(RefreshDashboard(repo)),
  ];
}
