import 'dart:io';

import '../../../../core/debug/app_talker.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/browser_cookie.dart';
import '../../domain/entities/cookie_source.dart';
import '../../domain/repositories/browser_cookie_repository.dart';
import '../../domain/value_objects/cookie_browser.dart';
import '../../domain/value_objects/cookie_read_problem.dart';
import '../datasources/browser_cookies/chromium_cookie_reader.dart';
import '../datasources/browser_cookies/firefox_cookie_reader.dart';
import '../datasources/browser_cookies/safari_cookie_reader.dart';
import '../datasources/browser_cookies/sqlite_snapshot.dart';

/// The browsers' cookies on this device: Chromium browsers on macOS and
/// Windows, Safari on macOS, Firefox anywhere.
class LocalBrowserCookieRepository implements BrowserCookieRepository {
  LocalBrowserCookieRepository({
    required this._chromium,
    required this._firefox,
    required this._safari,
  });

  final ChromiumCookieReader _chromium;
  final FirefoxCookieReader _firefox;
  final SafariCookieReader _safari;

  /// errno for a permission the system refused (EPERM, EACCES).
  static const _refused = {1, 13};

  /// Each browser is looked for on its own: one that cannot be looked at
  /// (a folder the system refuses, a malformed `profiles.ini`) is logged and
  /// skipped, and fails the lookup only when no other browser was found —
  /// so it is never mistaken for "no browser here".
  @override
  Future<Result<List<CookieSource>>> sources() async {
    final found = <CookieSource>[];
    Object? firstError;
    Future<void> look(
      CookieBrowser browser,
      Future<List<({String path, String name})>> Function() profiles,
    ) async {
      try {
        found.addAll([
          for (final profile in await profiles())
            CookieSource(
              browser: browser,
              profileId: profile.path,
              profileName: profile.name,
            ),
        ]);
      } on Object catch (e) {
        firstError ??= e;
        appTalker.warning(
          'Cookie import: looking for ${browser.name} failed: $e',
        );
      }
    }

    for (final browser in CookieBrowser.values.where((b) => b.isChromium)) {
      await look(browser, () => _chromium.profiles(browser));
    }
    await look(CookieBrowser.firefox, _firefox.profiles);
    await look(
      CookieBrowser.safari,
      () async => [if (_safari.installed) (path: 'safari', name: 'Safari')],
    );
    if (found.isEmpty && firstError != null) {
      return Err(
        StorageFailure('Could not look for browsers', cause: firstError),
      );
    }
    return Ok(found);
  }

  @override
  Future<Result<List<BrowserCookie>>> read(CookieSource source) async {
    final result = await _read(source);
    if (result case Err(:final failure)) {
      appTalker.warning(
        'Cookie import: reading ${source.browser.name} failed: '
        '${failure.message} (${failure.cause})',
      );
    }
    return result;
  }

  Future<Result<List<BrowserCookie>>> _read(CookieSource source) async {
    try {
      return Ok(switch (source.browser) {
        CookieBrowser.firefox => await _firefox.read(source.profileId),
        CookieBrowser.safari => await _safari.read(),
        _ => await _chromium.read(source.browser, source.profileId),
      });
    } on KeychainDeniedException catch (e) {
      return Err(AuthFailure('The keychain refused the password', cause: e));
    } on KeychainTimeoutException catch (e) {
      return Err(
        ExpiredFailure('The keychain prompt went unanswered', cause: e),
      );
    } on CookieStoreInUseException {
      return const Err(
        StorageFailure(
          'The browser holds its cookies locked',
          cause: CookieReadProblem.browserBusy,
        ),
      );
    } on AppBoundEncryptionException {
      return const Err(
        StorageFailure(
          'Only the browser itself can decrypt its cookies',
          cause: CookieReadProblem.appBoundEncryption,
        ),
      );
    } on FileSystemException catch (e) {
      if (_refused.contains(e.osError?.errorCode)) {
        return Err(AuthFailure('The system refused access', cause: e));
      }
      return Err(StorageFailure('Could not read the cookies', cause: e));
    } on Object catch (e) {
      // Errors too (a RemoteError from the reading isolate, a cookie row of
      // an unexpected shape): one thrown past here left the import spinning.
      return Err(StorageFailure('Could not read the cookies', cause: e));
    }
  }
}
