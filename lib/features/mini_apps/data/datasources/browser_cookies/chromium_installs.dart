import '../../../domain/value_objects/cookie_browser.dart';
import 'join_path.dart';

/// The keychain item holding [browser]'s cookie password on macOS; every
/// release channel of a browser shares it.
String? chromiumKeychainService(CookieBrowser browser) => switch (browser) {
  CookieBrowser.chrome => 'Chrome Safe Storage',
  CookieBrowser.edge => 'Microsoft Edge Safe Storage',
  CookieBrowser.brave => 'Brave Safe Storage',
  CookieBrowser.arc => 'Arc Safe Storage',
  CookieBrowser.chromium => 'Chromium Safe Storage',
  CookieBrowser.vivaldi => 'Vivaldi Safe Storage',
  CookieBrowser.opera => 'Opera Safe Storage',
  CookieBrowser.firefox || CookieBrowser.safari => null,
};

/// The folders [browser] may keep its data in on [os] (as
/// `Platform.operatingSystem` names it), one per release channel. Each holds
/// `Local State` and the profile folders; Opera's is a profile itself.
///
/// Arc on Windows lives in a Store package whose folder name is not fixed:
/// see [arcWindowsPackagePrefix].
List<String> chromiumDataDirs(
  CookieBrowser browser, {
  required String os,
  required Map<String, String> environment,
}) {
  String? dir(String name) {
    final value = environment[name];
    return value == null || value.isEmpty ? null : value;
  }

  switch (os) {
    case 'macos':
      final home = dir('HOME');
      if (home == null) return const [];
      return [
        for (final d in _macDirs(browser))
          joinPath([home, 'Library/Application Support', d]),
      ];
    case 'windows':
      final local = dir('LOCALAPPDATA');
      final roaming = dir('APPDATA');
      return [
        if (local != null)
          for (final d in _windowsLocalDirs(browser)) joinPath([local, d]),
        if (roaming != null && browser == CookieBrowser.opera)
          joinPath([roaming, 'Opera Software/Opera Stable']),
      ];
  }
  return const [];
}

/// The start of Arc's Store package folder under `%LOCALAPPDATA%\Packages`,
/// and where its data sits inside it.
const arcWindowsPackagePrefix = 'TheBrowserCompany.Arc_';
const arcWindowsDataDir = 'LocalCache/Local/Arc/User Data';

List<String> _macDirs(CookieBrowser browser) => switch (browser) {
  CookieBrowser.chrome => const [
    'Google/Chrome',
    'Google/Chrome Beta',
    'Google/Chrome Dev',
    'Google/Chrome Canary',
  ],
  CookieBrowser.edge => const [
    'Microsoft Edge',
    'Microsoft Edge Beta',
    'Microsoft Edge Dev',
    'Microsoft Edge Canary',
  ],
  CookieBrowser.brave => const [
    'BraveSoftware/Brave-Browser',
    'BraveSoftware/Brave-Browser-Beta',
    'BraveSoftware/Brave-Browser-Nightly',
  ],
  CookieBrowser.arc => const ['Arc/User Data'],
  CookieBrowser.chromium => const ['Chromium'],
  CookieBrowser.vivaldi => const ['Vivaldi'],
  CookieBrowser.opera => const ['com.operasoftware.Opera'],
  CookieBrowser.firefox || CookieBrowser.safari => const [],
};

List<String> _windowsLocalDirs(CookieBrowser browser) => switch (browser) {
  CookieBrowser.chrome => const [
    'Google/Chrome/User Data',
    'Google/Chrome Beta/User Data',
    'Google/Chrome Dev/User Data',
    'Google/Chrome SxS/User Data',
  ],
  CookieBrowser.edge => const [
    'Microsoft/Edge/User Data',
    'Microsoft/Edge Beta/User Data',
    'Microsoft/Edge Dev/User Data',
    'Microsoft/Edge SxS/User Data',
  ],
  CookieBrowser.brave => const [
    'BraveSoftware/Brave-Browser/User Data',
    'BraveSoftware/Brave-Browser-Beta/User Data',
    'BraveSoftware/Brave-Browser-Nightly/User Data',
  ],
  CookieBrowser.chromium => const ['Chromium/User Data'],
  CookieBrowser.vivaldi => const ['Vivaldi/User Data'],
  CookieBrowser.arc ||
  CookieBrowser.opera ||
  CookieBrowser.firefox ||
  CookieBrowser.safari => const [],
};
