import '../entities/mini_app_permission.dart';
import '../repositories/mini_app_permission_repository.dart';

/// What to do with a page's request for [kinds]: the remembered answer when
/// every kind has one (allowed only if all are), else null — ask the user.
/// A storage failure also asks: better a prompt than a silent grant.
class ResolveMiniAppPermission {
  const ResolveMiniAppPermission(this._repository);

  final MiniAppPermissionRepository _repository;

  Future<MiniAppPermissionDecision?> call(
    String miniAppId,
    Iterable<MiniAppPermissionKind> kinds,
  ) async {
    var allowed = true;
    for (final kind in kinds.toSet()) {
      final res = await _repository.decisionFor(miniAppId, kind);
      final decision = res.valueOrNull;
      if (decision == null) return null;
      if (decision == MiniAppPermissionDecision.block) allowed = false;
    }
    return allowed
        ? MiniAppPermissionDecision.allow
        : MiniAppPermissionDecision.block;
  }
}
