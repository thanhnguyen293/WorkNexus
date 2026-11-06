import '../../../../core/error/result.dart';
import '../entities/cookie_import.dart';
import '../repositories/cookie_import_repository.dart';
import '../repositories/web_view_cookie_repository.dart';

/// The imported sites, each with how many of its sign-in cookies the web view
/// no longer has: expired, signed out or cleared. Such a site wants importing
/// again.
class CheckCookieImports {
  const CheckCookieImports(this._imports, this._webView);

  final CookieImportRepository _imports;
  final WebViewCookieRepository _webView;

  Future<Result<List<CookieImportState>>> call() async {
    final List<CookieImport> imports;
    switch (await _imports.all()) {
      case Ok(:final value):
        imports = value;
      case Err(:final failure):
        return Err(failure);
    }
    final states = <CookieImportState>[];
    for (final import in imports) {
      switch (await _webView.present(import.keys)) {
        case Ok(:final value):
          states.add(
            CookieImportState(
              import: import,
              missing: import.keys.where((k) => !value.contains(k)).length,
            ),
          );
        case Err(:final failure):
          return Err(failure);
      }
    }
    return Ok(states);
  }
}
