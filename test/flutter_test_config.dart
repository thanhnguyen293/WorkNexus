import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Auto-loaded by `flutter test` before any test. The default UI font (Be
/// Vietnam Pro) is served by `google_fonts`, which would otherwise try to fetch
/// over the network while building the theme in tests. Disable runtime fetching
/// so tests stay offline and deterministic — google_fonts falls back to the
/// bundled sans instead.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
