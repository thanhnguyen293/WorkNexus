/// Compile-time application identity constants.
///
/// Values are injected at build time via `--dart-define-from-file=.env`
/// and fall back to the default production values when not provided.
///
/// Override for a custom build:
/// ```sh
/// # .env.staging
/// APP_NAME=WorkNexus Staging
/// GITHUB_OWNER=my-org
/// GITHUB_REPO=my-fork
///
/// flutter run --dart-define-from-file=.env.staging
/// ```
abstract final class AppConfig {
  /// Human-readable product name shown in window titles, notifications, and
  /// the Windows AppUserModelID.
  static const appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'WorkNexus',
  );

  /// GitHub organisation that owns the release repository, used by the update
  /// checker to construct the Releases API URL.
  static const githubOwner = String.fromEnvironment(
    'GITHUB_OWNER',
    defaultValue: 'thanhnguyen293',
  );

  /// GitHub repository name, paired with [githubOwner] for the Releases API.
  static const githubRepo = String.fromEnvironment(
    'GITHUB_REPO',
    defaultValue: 'WorkNexus',
  );

  /// macOS bundle identifier (must match `macos/Runner/Configs/AppInfo.xcconfig`).
  /// Used to open this app's page in System Settings → Notifications.
  static const macBundleId = String.fromEnvironment(
    'MAC_BUNDLE_ID',
    defaultValue: 'com.worknexus.workNexus',
  );

  /// Linux application id: the `.desktop` entry's name and the window's
  /// class, by which docks tie the window (and its badge) to the entry. Must
  /// match `APPLICATION_ID` in `linux/CMakeLists.txt`.
  static const linuxAppId = 'com.worknexus.workNexus';

  /// Windows AppUserModelID — ties toast notifications to this app entry.
  /// Must stay stable across releases or Windows treats it as a different app.
  static const windowsAppId = String.fromEnvironment(
    'WINDOWS_APP_ID',
    defaultValue: 'WorkNexus.WorkNexus.Desktop',
  );

  /// COM activator GUID for Windows toast notifications.
  /// Must stay stable across releases — see [windowsAppId].
  static const windowsGuid = String.fromEnvironment(
    'WINDOWS_GUID',
    defaultValue: 'c14901d9-c46d-4d26-9596-9c14e5a0e0b7',
  );

  /// SQLite database filename (without extension).
  static const databaseName = String.fromEnvironment(
    'DB_NAME',
    defaultValue: 'worknexus',
  );

  // Release assets are named `WorkNexus-<os>-<arch>.<ext>`. Builds before
  // that naming looked for worknexus-windows.zip, work_nexus-macos.zip and
  // worknexus-linux-x64.tar.gz, so CI also publishes each archive under its
  // old name (and checksums it) until those builds have updated. The updater
  // matches names case-insensitively, as GitHub does.

  /// Release asset holding the Windows build (zip of the Release folder).
  static const updateAssetWindows = String.fromEnvironment(
    'UPDATE_ASSET_WINDOWS',
    defaultValue: 'WorkNexus-windows-x64.zip',
  );

  /// Release asset holding the macOS build (zipped `.app`).
  static const updateAssetMacos = String.fromEnvironment(
    'UPDATE_ASSET_MACOS',
    defaultValue: 'WorkNexus-macos-universal.zip',
  );

  /// Release asset holding the Linux build (tarball of the bundle folder).
  static const updateAssetLinux = String.fromEnvironment(
    'UPDATE_ASSET_LINUX',
    defaultValue: 'WorkNexus-linux-x64.tar.gz',
  );

  /// Release asset holding the Linux build as one AppImage file, which an app
  /// started from an AppImage updates from instead of the tarball.
  static const updateAssetAppImage = String.fromEnvironment(
    'UPDATE_ASSET_APPIMAGE',
    defaultValue: 'WorkNexus-linux-x64.AppImage',
  );

  /// Release asset holding the Linux build as a Debian package, which an app
  /// installed from the .deb updates from: its bundle in /opt is root-owned
  /// and dpkg-managed, so it is reinstalled through the package manager.
  static const updateAssetDeb = String.fromEnvironment(
    'UPDATE_ASSET_DEB',
    defaultValue: 'WorkNexus-linux-x64.deb',
  );

  /// Release asset listing `sha256  filename` lines the updater verifies
  /// a download against.
  static const updateChecksumsAsset = String.fromEnvironment(
    'UPDATE_CHECKSUMS_ASSET',
    defaultValue: 'SHA256SUMS.txt',
  );
}
