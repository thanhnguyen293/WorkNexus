import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/platform/desktop_notifier.dart';
import '../../domain/entities/mini_app.dart';
import '../../domain/entities/mini_app_permission.dart';
import '../../domain/repositories/mini_app_permission_repository.dart';
import '../../domain/repositories/mini_app_repository.dart';
import '../../domain/usecases/add_mini_app.dart';
import '../../domain/usecases/resolve_mini_app_permission.dart';
import '../../domain/usecases/update_mini_app.dart';

// The feature's dependencies, as providers over the composition root: every
// controller below reads them from here, so a test replaces one with a fake
// instead of reaching into the service locator.
final miniAppRepositoryProvider = Provider<MiniAppRepository>(
  (ref) => getIt<MiniAppRepository>(),
);

final miniAppPermissionRepositoryProvider =
    Provider<MiniAppPermissionRepository>(
      (ref) => getIt<MiniAppPermissionRepository>(),
    );

final addMiniAppProvider = Provider<AddMiniApp>((ref) => getIt<AddMiniApp>());

final updateMiniAppProvider = Provider<UpdateMiniApp>(
  (ref) => getIt<UpdateMiniApp>(),
);

final resolveMiniAppPermissionProvider = Provider<ResolveMiniAppPermission>(
  (ref) => getIt<ResolveMiniAppPermission>(),
);

/// OS notifications, for what a mini app's page asks to show.
final miniAppNotifierProvider = Provider<DesktopNotifier>(
  (ref) => getIt<DesktopNotifier>(),
);

/// The user's mini apps in rail order, watched from the database.
final miniAppsProvider = StreamProvider<List<MiniApp>>(
  (ref) => ref.watch(miniAppRepositoryProvider).watchAll(),
);

/// Whether mini app [id] is the one on screen.
final miniAppShownProvider = Provider.family<bool, String>(
  (ref, id) =>
      ref.watch(selectedMainViewProvider) == MainView.miniApp &&
      ref.watch(openMiniAppIdProvider) == id,
);

/// [app] as the database has it now — edited since it was handed over, say —
/// or [app] itself when it is not there (yet).
MiniApp currentMiniApp(WidgetRef ref, MiniApp app) =>
    ref
        .read(miniAppsProvider)
        .asData
        ?.value
        .where((a) => a.id == app.id)
        .firstOrNull ??
    app;

/// What the user allowed or blocked for one mini app, live.
final miniAppPermissionsProvider =
    StreamProvider.family<List<MiniAppPermissionGrant>, String>(
      (ref, miniAppId) =>
          ref.watch(miniAppPermissionRepositoryProvider).watch(miniAppId),
    );

/// Commands over the mini apps. Adding goes through [AddMiniApp] (URL
/// validation); editing through [UpdateMiniApp]; the rest are CRUD
/// pass-throughs to the repository interface.
class MiniAppController extends Notifier<void> {
  @override
  void build() {}

  MiniAppRepository get _repository => ref.read(miniAppRepositoryProvider);

  Future<Result<MiniApp>> add({required String url, String name = ''}) =>
      ref.read(addMiniAppProvider)(
        url: url,
        name: name,
        existing: ref.read(miniAppsProvider).value ?? const <MiniApp>[],
      );

  Future<Result<MiniApp>> update({
    required MiniApp app,
    required String url,
    required String name,
    required String? iconPath,
  }) => ref.read(updateMiniAppProvider)(
    app: app,
    url: url,
    name: name,
    iconPath: iconPath,
  );

  Future<Result<String?>> fetchSiteIcon(String id, String url) =>
      _repository.fetchSiteIcon(id: id, pageUrl: url);

  Future<Result<String>> importIcon(String id, String sourcePath) =>
      _repository.importIcon(id: id, sourcePath: sourcePath);

  Future<Result<void>> rememberPage(String id, String url) =>
      _repository.saveLastUrl(id, url);

  Future<Result<void>> remove(String id) => _repository.delete(id);
}

final miniAppControllerProvider = NotifierProvider<MiniAppController, void>(
  MiniAppController.new,
);

/// Commands over the permissions pages ask for.
class MiniAppPermissionController extends Notifier<void> {
  @override
  void build() {}

  MiniAppPermissionRepository get _repository =>
      ref.read(miniAppPermissionRepositoryProvider);

  /// The remembered answer for [kinds]; null when the user must be asked.
  Future<MiniAppPermissionDecision?> remembered(
    String miniAppId,
    Iterable<MiniAppPermissionKind> kinds,
  ) => ref.read(resolveMiniAppPermissionProvider)(miniAppId, kinds);

  /// Keeps the user's answer for each of [kinds]; the first failure, if one
  /// could not be kept.
  Future<Result<void>> remember(
    String miniAppId,
    Iterable<MiniAppPermissionKind> kinds,
    MiniAppPermissionDecision decision,
  ) async {
    Result<void> result = const Ok(null);
    for (final kind in kinds.toSet()) {
      final saved = await _repository.save(
        MiniAppPermissionGrant(
          miniAppId: miniAppId,
          kind: kind,
          decision: decision,
        ),
      );
      if (saved.isErr && !result.isErr) result = saved;
    }
    return result;
  }

  /// Forgets an answer: the page is asked about it again next time.
  Future<Result<void>> forget(String miniAppId, MiniAppPermissionKind kind) =>
      _repository.clear(miniAppId, kind);
}

final miniAppPermissionControllerProvider =
    NotifierProvider<MiniAppPermissionController, void>(
      MiniAppPermissionController.new,
    );
