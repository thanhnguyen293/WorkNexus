import '../../../../core/error/failure.dart';
import '../../../../core/error/guard_storage.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/browser_cookie.dart';
import '../../domain/repositories/web_view_cookie_repository.dart';
import '../../domain/value_objects/cookie_key.dart';
import '../datasources/web_view_cookie_datasource.dart';

/// [WebViewCookieRepository] over the web view's cookie store.
class LocalWebViewCookieRepository implements WebViewCookieRepository {
  const LocalWebViewCookieRepository(this._web);

  final WebViewCookieDatasource _web;

  @override
  bool get canWrite => _web.supported;

  @override
  Future<Result<void>> write(List<BrowserCookie> cookies) async {
    if (!canWrite) return const Err(StorageFailure('Not supported here'));
    final result = await guardStorage('Could not set the cookies', () async {
      var refused = 0;
      for (final cookie in cookies) {
        if (!await _web.write(cookie)) refused++;
      }
      return refused;
    });
    return switch (result) {
      Ok(:final value) when value == cookies.length => const Err(
        StorageFailure('The web view refused the cookies'),
      ),
      Ok() => const Ok(null),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<Set<CookieKey>>> present(List<CookieKey> keys) {
    if (!canWrite) {
      return Future.value(const Err(StorageFailure('Not supported here')));
    }
    return guardStorage('Could not read the cookies', () => _web.present(keys));
  }
}
