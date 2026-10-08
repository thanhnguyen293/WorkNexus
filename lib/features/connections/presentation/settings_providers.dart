import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/domain/adapters/opencode_cli.dart';

/// Whether the "add provider" picker is expanded on the settings page.
final connectPickerOpenProvider = StateProvider<bool>((ref) => false);

/// The `provider/model` ids OpenCode can translate with, for the Settings
/// picker. Empty when the CLI can't be asked, in which case the picker says so
/// and keeps whatever model is already pinned.
///
/// Cached for the session (no `autoDispose`) on purpose: asking the CLI spawns a
/// subprocess that takes seconds, and the installed model list doesn't change
/// while the app is open — re-running it on every visit to Settings would make
/// the page feel broken. Widget tests override this so they never shell out.
final openCodeModelsProvider = FutureProvider<List<String>>(
  (ref) => getIt<OpenCodeCli>().listModels(),
);
