import '../../../../core/error/guard_storage.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/mini_app_permission.dart';
import '../../domain/repositories/mini_app_permission_repository.dart';
import '../datasources/mini_app_permission_local_datasource.dart';
import '../mappers/mini_app_permission_mapper.dart';

/// [MiniAppPermissionRepository] over the local database.
class LocalMiniAppPermissionRepository implements MiniAppPermissionRepository {
  const LocalMiniAppPermissionRepository(this._local);

  final MiniAppPermissionLocalDatasource _local;

  static const _failure = 'Could not keep the permission';

  @override
  Stream<List<MiniAppPermissionGrant>> watch(String miniAppId) => _local
      .watch(miniAppId)
      .map(
        (rows) => [
          for (final row in rows) ?MiniAppPermissionMapper.fromRow(row),
        ],
      );

  @override
  Future<Result<MiniAppPermissionDecision?>> decisionFor(
    String miniAppId,
    MiniAppPermissionKind kind,
  ) => guardStorage(_failure, () async {
    final row = await _local.read(miniAppId, kind.name);
    if (row == null) return null;
    return row.allowed
        ? MiniAppPermissionDecision.allow
        : MiniAppPermissionDecision.block;
  });

  @override
  Future<Result<void>> save(MiniAppPermissionGrant grant) => guardStorage(
    _failure,
    () => _local.save(MiniAppPermissionMapper.toRow(grant)),
  );

  @override
  Future<Result<void>> clear(String miniAppId, MiniAppPermissionKind kind) =>
      guardStorage(_failure, () => _local.clear(miniAppId, kind.name));
}
