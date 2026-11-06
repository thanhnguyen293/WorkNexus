import '../../domain/value_objects/cookie_browser.dart';

/// The browser's product name, the same in every language.
String cookieBrowserName(CookieBrowser browser) => switch (browser) {
  CookieBrowser.chrome => 'Chrome',
  CookieBrowser.edge => 'Edge',
  CookieBrowser.brave => 'Brave',
  CookieBrowser.arc => 'Arc',
  CookieBrowser.firefox => 'Firefox',
  CookieBrowser.safari => 'Safari',
};
