import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../domain/entities/mini_app.dart';
import '../../domain/repositories/mini_app_browsing_data_repository.dart';
import 'mini_app_browser_controller.dart';
import 'mini_app_providers.dart';

/// Clears what the mini apps' pages keep (CRUD pass-throughs to
/// [MiniAppBrowsingDataRepository]). Its state is the job running, if any:
/// [cacheJob], [allJob] or the id of the app being cleared. Open pages reload
/// afterwards, so none keeps a sign-in it no longer has.
class MiniAppBrowsingDataController extends Notifier<String?> {
  static const cacheJob = '#cache';
  static const allJob = '#all';

  @override
  String? build() => null;

  bool get canClear => ref.read(miniAppBrowsingDataRepositoryProvider).canClear;

  Future<Result<void>> clearCache(List<MiniApp> apps) =>
      _job(cacheJob, apps, (repo) => repo.clearCache());

  Future<Result<void>> clearSite(MiniApp app) =>
      _job(app.id, [app], (repo) => repo.clearSite(app.url));

  Future<Result<void>> clearAll(List<MiniApp> apps) => _job(
    allJob,
    apps,
    (repo) => repo.clearAll([for (final a in apps) a.url]),
  );

  Future<Result<void>> _job(
    String job,
    List<MiniApp> reload,
    Future<Result<void>> Function(MiniAppBrowsingDataRepository repo) run,
  ) async {
    state = job;
    final result = await run(ref.read(miniAppBrowsingDataRepositoryProvider));
    if (!ref.mounted) return result;
    state = null;
    if (result.isOk) {
      for (final app in reload) {
        if (ref.exists(miniAppBrowserProvider(app.id))) {
          ref.read(miniAppBrowserProvider(app.id).notifier).reload();
        }
      }
    }
    return result;
  }
}

final miniAppBrowsingDataControllerProvider =
    NotifierProvider.autoDispose<MiniAppBrowsingDataController, String?>(
      MiniAppBrowsingDataController.new,
    );
