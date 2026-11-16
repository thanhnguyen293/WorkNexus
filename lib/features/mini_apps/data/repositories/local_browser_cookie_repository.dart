import 'dart:io';

import '../../../../core/debug/app_talker.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/browser_cookie.dart';
import '../../domain/entities/cookie_source.dart';
import '../../domain/repositories/browser_cookie_repository.dart';
import '../../domain/value_objects/cookie_browser.dart';
import '../datasources/browser_cookies/chromium_cookie_reader.dart';
import '../datasources/browser_cookies/firefox_cookie_reader.dart';
import '../datasources/browser_cookies/safari_cookie_reader.dart';

/// The browsers' cookies on this device: Chromium browsers and Safari on
/// macOS, Firefox anywhere.
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

  @override
  Future<Result<List<CookieSource>>> sources() async {
    try {
      return Ok([
        for (final browser in CookieBrowser.values.where((b) => b.isChromium))
          for (final profile in await _chromium.profiles(browser))
            CookieSource(
              browser: browser,
              profileId: profile.path,
              profileName: profile.name,
            ),
        for (final profile in await _firefox.profiles())
          CookieSource(
            browser: CookieBrowser.firefox,
            profileId: profile.path,
            profileName: profile.name,
          ),
        if (_safari.installed)
          const CookieSource(
            browser: CookieBrowser.safari,
            profileId: 'safari',
            profileName: 'Safari',
          ),
      ]);
    } on Exception catch (e) {
      return Err(StorageFailure('Could not look for browsers', cause: e));
    }
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
