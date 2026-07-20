import 'dart:io';

/// Opens [url] in the user's default handler — the desktop `open` launcher
/// (macOS). Used for "open in browser" affordances (external ticket links,
/// image fallbacks, token-settings pages).
///
/// Best-effort: nothing is surfaced if it fails (e.g. a platform without
/// `open`), so callers can wire it straight to a tap handler.
Future<void> openExternally(String url) async {
  try {
    await Process.run('open', [url]);
  } catch (_) {
    // Nothing to surface if the platform lacks `open`.
  }
}
