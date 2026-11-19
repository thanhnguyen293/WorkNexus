/// Why a browser's cookies could not be read, when the user can do something
/// about it. Carried as the `cause` of the read's failure.
enum CookieReadProblem {
  /// The browser is running and holds its cookie file locked (Windows).
  browserBusy,

  /// The browser encrypts its cookies so that only it can read them (Chrome's
  /// app-bound encryption on Windows).
  appBoundEncryption,
}
