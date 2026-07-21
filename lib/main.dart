import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:injectable/injectable.dart';

import 'app/app.dart';
import 'core/database/database.dart';
import 'core/di/service_locator.dart';
import 'core/platform/desktop_window_service.dart';
import 'core/settings/app_settings.dart';
import 'data/local/database_seeder.dart';
import 'data/local/mappers.dart';
import 'features/sync/data/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await const DesktopWindowService().initialize();

  // Wire the object graph (repositories, services) for production via
  // injectable. The composition root constructs the drift database; retrieve it
  // to run the one-time demo-data purge and load persisted settings before the
  // UI mounts. Local-first: drift is the read model, and the board starts empty
  // until you connect a provider (ZenTao).
  await configureDependencies(Environment.prod);
  final db = getIt<AppDatabase>();
  await purgeSeededDemoData(db);

  // Scope the on-disk attachment cache to a single session: clear last
  // session's downloaded repro videos/screenshots so temp doesn't accumulate.
  await getIt<SyncService>().purgeAttachmentCache();

  // Restore persisted appearance/language settings (defaults on first run).
  final settingsRow = await db.getSettings();
  final initialSettings = settingsRow == null
      ? const AppSettings()
      : appSettingsFromRow(settingsRow);

  runApp(
    ProviderScope(
      overrides: [
        // Seed settings from drift and persist every change back to it. Settings
        // are reactive UI state (Riverpod), so they stay a provider override.
        initialAppSettingsProvider.overrideWithValue(initialSettings),
        settingsPersistProvider.overrideWithValue(
          (s) => db.saveSettings(appSettingsToCompanion(s)),
        ),
      ],
      child: const WorkNexusApp(),
    ),
  );
}
