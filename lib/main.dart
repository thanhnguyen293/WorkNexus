import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/database/database.dart';
import 'core/di/providers.dart';
import 'core/platform/desktop_window_service.dart';
import 'core/settings/app_settings.dart';
import 'data/local/database_seeder.dart';
import 'data/local/mappers.dart';
import 'data/local/repositories/empty_dev_link_repository.dart';
import 'data/local/repositories/local_activity_repository.dart';
import 'data/local/repositories/local_comment_repository.dart';
import 'data/local/repositories/local_ticket_repository.dart';
import 'data/local/repositories/local_workspace_repository.dart';
import 'features/translation/data/opencode_translation_service.dart';
import 'features/translation/data/repositories/local_translation_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await const DesktopWindowService().initialize();

  // Local-first: drift is the read model. Real data only — the board starts
  // empty until you connect a provider (ZenTao). Any previously-seeded demo
  // dataset is removed on launch (idempotent).
  final db = AppDatabase();
  await purgeSeededDemoData(db);

  // Restore persisted appearance/language settings (defaults on first run).
  final settingsRow = await db.getSettings();
  final initialSettings = settingsRow == null
      ? const AppSettings()
      : appSettingsFromRow(settingsRow);

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        // Seed settings from drift and persist every change back to it.
        initialAppSettingsProvider.overrideWithValue(initialSettings),
        settingsPersistProvider.overrideWithValue(
          (s) => db.saveSettings(appSettingsToCompanion(s)),
        ),
        // Swap the persistent repositories from fixtures → drift. UI, use cases,
        // and domain are untouched — the Dependency Rule paying off.
        ticketRepositoryProvider.overrideWith(
          (ref) => LocalTicketRepository(ref.watch(appDatabaseProvider)),
        ),
        workspaceRepositoryProvider.overrideWith(
          (ref) => LocalWorkspaceRepository(ref.watch(appDatabaseProvider)),
        ),
        commentRepositoryProvider.overrideWith(
          (ref) => LocalCommentRepository(ref.watch(appDatabaseProvider)),
        ),
        translationRepositoryProvider.overrideWith(
          (ref) => LocalTranslationRepository(ref.watch(appDatabaseProvider)),
        ),
        // Real-data only: activity persisted from the provider; no fabricated
        // dev links.
        activityRepositoryProvider.overrideWith(
          (ref) => LocalActivityRepository(ref.watch(appDatabaseProvider)),
        ),
        devLinkRepositoryProvider.overrideWith(
          (ref) => const EmptyDevLinkRepository(),
        ),
        // Real OpenCode-backed translation, using OpenCode's own auth + default
        // model so runs show up in your OpenCode usage/quota.
        translationServiceProvider.overrideWith(
          (ref) => OpenCodeTranslationService(),
        ),
      ],
      child: const WorkNexusApp(),
    ),
  );
}
