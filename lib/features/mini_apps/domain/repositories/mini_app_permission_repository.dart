import '../../../../core/error/result.dart';
import '../entities/mini_app_permission.dart';

/// The permissions the user gave (or refused) each mini app, kept on this
/// device.
abstract interface class MiniAppPermissionRepository {
  /// The answers remembered for app [miniAppId], live.
  Stream<List<MiniAppPermissionGrant>> watch(String miniAppId);

  /// The remembered answer for [kind]; null when never asked (or cleared).
  Future<Result<MiniAppPermissionDecision?>> decisionFor(
    String miniAppId,
    MiniAppPermissionKind kind,
  );

  /// Remembers [grant], replacing the earlier answer for its kind.
  Future<Result<void>> save(MiniAppPermissionGrant grant);

  /// Forgets the answer for [kind], so the next request asks again.
  Future<Result<void>> clear(String miniAppId, MiniAppPermissionKind kind);
}
