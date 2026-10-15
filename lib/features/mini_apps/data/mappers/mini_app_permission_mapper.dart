import '../../../../core/database/database.dart';
import '../../domain/entities/mini_app_permission.dart';

/// [MiniAppPermissionGrant] ↔ its drift row. A row naming a kind this build
/// does not know (written by a newer one) is skipped.
abstract final class MiniAppPermissionMapper {
  static MiniAppPermissionGrant? fromRow(MiniAppPermissionRow row) {
    final kind = MiniAppPermissionKind.values
        .where((k) => k.name == row.kind)
        .firstOrNull;
    if (kind == null) return null;
    return MiniAppPermissionGrant(
      miniAppId: row.miniAppId,
      kind: kind,
      decision: row.allowed
          ? MiniAppPermissionDecision.allow
          : MiniAppPermissionDecision.block,
    );
  }

  static MiniAppPermissionsCompanion toRow(MiniAppPermissionGrant grant) =>
      MiniAppPermissionsCompanion.insert(
        miniAppId: grant.miniAppId,
        kind: grant.kind.name,
        allowed: grant.decision == MiniAppPermissionDecision.allow,
      );
}
