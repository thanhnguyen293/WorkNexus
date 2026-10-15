import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/mini_app.dart';
import '../../domain/repositories/mini_app_repository.dart';
import '../../domain/usecases/add_mini_app.dart';
import '../../domain/usecases/update_mini_app.dart';

/// The user's mini apps in rail order, watched from the database.
final miniAppsProvider = StreamProvider<List<MiniApp>>(
  (ref) => getIt<MiniAppRepository>().watchAll(),
);

/// Commands over the mini apps. Adding goes through [AddMiniApp] (URL
/// validation); editing through [UpdateMiniApp]; the rest are CRUD
/// pass-throughs to the repository interface.
class MiniAppController extends Notifier<void> {
  @override
  void build() {}

  Future<Result<MiniApp>> add({required String url, String name = ''}) =>
      getIt<AddMiniApp>()(
        url: url,
        name: name,
        existing: ref.read(miniAppsProvider).value ?? const <MiniApp>[],
      );

  Future<Result<MiniApp>> update({
    required MiniApp app,
    required String url,
    required String name,
    required String? iconPath,
  }) => getIt<UpdateMiniApp>()(
    app: app,
    url: url,
    name: name,
    iconPath: iconPath,
  );

  Future<Result<String?>> fetchSiteIcon(String id, String url) =>
      getIt<MiniAppRepository>().fetchSiteIcon(id: id, pageUrl: url);

  Future<Result<String>> importIcon(String id, String sourcePath) =>
      getIt<MiniAppRepository>().importIcon(id: id, sourcePath: sourcePath);

  Future<Result<void>> rememberPage(String id, String url) =>
      getIt<MiniAppRepository>().saveLastUrl(id, url);

  Future<Result<void>> remove(String id) =>
      getIt<MiniAppRepository>().delete(id);
}

final miniAppControllerProvider = NotifierProvider<MiniAppController, void>(
  MiniAppController.new,
);
