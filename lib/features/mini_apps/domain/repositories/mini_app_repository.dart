import '../../../../core/error/result.dart';
import '../entities/mini_app.dart';

/// The mini apps the user added, kept on this device.
abstract interface class MiniAppRepository {
  /// Every mini app in rail order, live.
  Stream<List<MiniApp>> watchAll();

  /// Keeps [app], replacing the one with its id.
  Future<Result<void>> save(MiniApp app);

  /// Remembers [url] as the page app [id] was last on. Touches nothing else,
  /// so it cannot undo an edit made meanwhile.
  Future<Result<void>> saveLastUrl(String id, String url);

  /// Puts the apps in the order of [ids] on the rail, first to last. Touches
  /// nothing but their positions.
  Future<Result<void>> saveOrder(List<String> ids);

  /// Removes the app and its icon file.
  Future<Result<void>> delete(String id);

  /// Downloads the icon of the site at [pageUrl] for app [id] and keeps it on
  /// this device. Resolves to the image file's path, or null when the site
  /// offers none.
  Future<Result<String?>> fetchSiteIcon({
    required String id,
    required String pageUrl,
  });

  /// Copies the image at [sourcePath] in as app [id]'s icon; resolves to the
  /// kept file's path.
  Future<Result<String>> importIcon({
    required String id,
    required String sourcePath,
  });
}
