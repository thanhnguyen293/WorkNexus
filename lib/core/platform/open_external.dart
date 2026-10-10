import 'dart:io';

import 'package:flutter/foundation.dart';

/// Opens [url] in the user's default browser or URL handler.
/// Uses the platform-appropriate launcher: `open` on macOS, `rundll32.exe
/// url.dll,FileProtocolHandler` on Windows, and `xdg-open` on Linux.
/// Used for "open in browser" affordances (external ticket links,
/// image fallbacks, token-settings pages, release download links).
///
/// Best-effort: nothing is surfaced if it fails (e.g. a platform without
/// a registered URL handler), so callers can wire it straight to a tap handler.
Future<void> openExternally(String url) async {
  try {
    final executable = switch (defaultTargetPlatform) {
      TargetPlatform.windows => 'rundll32.exe',
      TargetPlatform.linux => 'xdg-open',
      _ => 'open',
    };
    final arguments = defaultTargetPlatform == TargetPlatform.windows
        ? ['url.dll,FileProtocolHandler', url]
        : [url];
    await Process.run(executable, arguments);
  } catch (_) {
    // Nothing to surface if the platform lacks `open`.
  }
}

/// Opens a link tapped in rendered content (a description, a comment) in the
/// browser. Only web/mail links: `open` would launch a scheme-less path (e.g. a
/// provider-relative `/zentao/…` href) as a local file.
Future<void> openLinkExternally(String url) async {
  final scheme = Uri.tryParse(url.trim())?.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https' && scheme != 'mailto') return;
  await openExternally(url.trim());
}
