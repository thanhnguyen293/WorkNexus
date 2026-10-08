/// Read-only questions the app asks the locally-installed `opencode` CLI.
///
/// A shared-kernel contract (CLAUDE.md 5.2): `translation` gates the Translate
/// action on it and `connections` fills the Settings model picker from it, while
/// `agents` owns the CLI-backed implementation. Presentation depends on this
/// interface, never on the process-spawning detail behind it.
abstract class OpenCodeCli {
  /// Whether OpenCode has at least one authenticated provider — i.e. whether a
  /// headless run has any chance of succeeding.
  Future<bool> hasAuthenticatedProvider();

  /// The `provider/model` ids the CLI reports. Empty when it can't be asked
  /// (not installed, not authenticated, too slow) — callers treat that as "no
  /// list available", not as an error.
  Future<List<String>> listModels();
}
