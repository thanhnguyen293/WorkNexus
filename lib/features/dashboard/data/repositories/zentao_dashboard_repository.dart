import 'dart:convert';

import '../../../../core/database/database.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/zentao_dashboard.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_local_datasource.dart';
import '../mappers/zentao_dashboard_mapper.dart';

/// Fetches the raw ZenTao `GET /user?fields=…` reply of an account. Injected by
/// the composition root, which routes it through the account's pooled client.
typedef ZenTaoUserInfoFetcher =
    Future<Result<Map<String, dynamic>>> Function(
      String accountId, {
      required String fields,
      required int limit,
    });

/// Syncs every ticket assigned to an account's user into the ticket store.
typedef AssignedWorkSyncer = Future<Result<int>> Function(String accountId);

/// [DashboardRepository] over ZenTao: stores the raw reply in drift and parses
/// it on read, so a better parser also applies to an already-stored snapshot.
class ZenTaoDashboardRepository implements DashboardRepository {
  ZenTaoDashboardRepository({
    required DashboardLocalDatasource local,
    required ZenTaoUserInfoFetcher fetch,
    required AssignedWorkSyncer syncAssigned,
    DateTime Function()? now,
  }) : _local = local,
       _fetch = fetch,
       _syncAssigned = syncAssigned,
       _now = now ?? DateTime.now;

  final DashboardLocalDatasource _local;
  final ZenTaoUserInfoFetcher _fetch;
  final AssignedWorkSyncer _syncAssigned;
  final DateTime Function() _now;

  @override
  Stream<ZenTaoDashboard?> watch(String accountId) =>
      _local.watch(accountId).map(_parse);

  @override
  Future<ZenTaoDashboard?> cached(String accountId) async =>
      _parse(await _local.read(accountId));

  @override
  Future<Result<void>> refresh(String accountId) async {
    final res = await _fetch(
      accountId,
      fields: kZenTaoDashboardFields,
      limit: kZenTaoDashboardListLimit,
    );
    switch (res) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        try {
          await _local.save(
            accountId: accountId,
            json: jsonEncode(value),
            fetchedAt: _now(),
          );
          return const Ok(null);
        } catch (e) {
          return Err(StorageFailure('Could not store the dashboard', cause: e));
        }
    }
  }

  @override
  Future<Result<void>> syncAssignedWork(String accountId) async {
    final res = await _syncAssigned(accountId);
    return res.fold((_) => const Ok(null), Err.new);
  }

  /// A snapshot that no longer decodes is treated as absent (refetched).
  ZenTaoDashboard? _parse(DashboardSnapshotRow? row) {
    if (row == null) return null;
    try {
      final json = jsonDecode(row.json);
      if (json is! Map) return null;
      return zenTaoDashboardFromJson(
        Map<String, dynamic>.from(json),
        accountId: row.accountId,
        fetchedAt: row.fetchedAt,
      );
    } on FormatException {
      return null;
    }
  }
}
