import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:injectable/injectable.dart';

import 'app/app.dart';
import 'app/di/service_locator.dart';
import 'app/shell/storage_dialog.dart';
import 'app/tool_registry.dart';
import 'core/data/mappers/mappers.dart';
import 'core/database/database.dart';
import 'core/database/database_seeder.dart';
import 'core/di/providers.dart';
import 'core/navigation/open_storage.dart';
import 'core/navigation/open_zentao_execution.dart';
import 'core/navigation/person_chip.dart';
import 'core/platform/app_http_overrides.dart';
import 'core/platform/app_icon_providers.dart';
import 'core/platform/app_icon_service.dart';
import 'core/platform/app_name_providers.dart';
import 'core/platform/app_name_service.dart';
import 'core/platform/desktop_app_lifecycle.dart';
import 'core/platform/desktop_single_instance_service.dart';
import 'core/platform/desktop_tray_service.dart';
import 'core/platform/desktop_window_service.dart';
import 'core/platform/linux_desktop_entry.dart';
import 'core/settings/app_settings.dart';
import 'core/tools/tool_registry_provider.dart';
import 'features/chat/presentation/widgets/chat_person_chip.dart';
import 'features/translation/domain/repositories/translation_api_config_repository.dart';
import 'shared/sync/data/sync_coordinator.dart';
import 'tools/zentao/presentation/util/open_execution_board.dart';

Future<void> main(List<String> arguments) async {
  HttpOverrides.global = AppHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  const window = DesktopWindowService();
  await const DesktopSingleInstanceService().initialize(arguments, window);
  await window.initialize();
  // A dev build would point the entry at build/; only a release registers.
  if (kReleaseMode && Platform.isLinux) {
    await LinuxDesktopEntry().ensureInstalled();
  }
  // The official video_player has no Windows/Linux implementation; fvp
  // (libmdk) provides one there, so chat videos play in-app everywhere.
  fvp.registerWith(
    options: {
      'platforms': ['windows', 'linux'],
    },
  );

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
  // Not awaited: a recursive delete of temp is nothing the first frame needs,
  // and no attachment is downloaded before a ticket is opened.
  unawaited(getIt<SyncCoordinator>().purgeAttachmentCache());

  // Restore persisted appearance/language settings (defaults on first run).
  final settingsRow = await db.getSettings();
  final initialSettings = settingsRow == null
      ? const AppSettings()
      : appSettingsFromRow(settingsRow);
  final lifecycle = DesktopAppLifecycle(
    window: window,
    tray: DesktopTrayService(),
  );
  await lifecycle.initialize(initialSettings.locale);
  // The icon the user chose, over the window and the tray the lines above
  // made; not awaited, the first frame does not need it.
  final appIcon = AppIconService(setTrayIcon: lifecycle.setTrayIcon);
  unawaited(appIcon.apply());
  final appName = AppNameService(setTrayToolTip: lifecycle.setTrayToolTip);
  unawaited(appName.apply());

  runApp(
    ProviderScope(
      overrides: [
        // Default tool registry (Phase 4 registers tool modules)
        toolRegistryProvider.overrideWithValue(defaultToolRegistry),
        // Seed settings from drift and persist every change back to it. Settings
        // are reactive UI state (Riverpod), so they stay a provider override.
        translatesWithApiKeyProvider.overrideWith(
          (ref) async =>
              (await getIt<TranslationApiConfigRepository>().load())
                  .valueOrNull
                  ?.isUsable ??
              false,
        ),
        initialAppSettingsProvider.overrideWithValue(initialSettings),
        appIconServiceProvider.overrideWithValue(appIcon),
        appNameServiceProvider.overrideWithValue(appName),
        settingsPersistProvider.overrideWithValue(
          (s) => db.saveSettings(appSettingsToCompanion(s)),
        ),
        // Ticket screens show people as chat knows them (photo, "verified",
        // tap to chat) without importing the chat feature.
        // One storage dialog spans chat files and the synced data; features
        // open it without importing each other.
        openStorageProvider.overrideWithValue(StorageDialog.show),
        // A bug's Execution field opens the board's task view.
        openZenTaoExecutionProvider.overrideWithValue(openExecutionBoard),
        personChipBuilderProvider.overrideWithValue(
          (context, {required accountId, required name, required avatarSize}) =>
              ChatPersonChip(
                accountId: accountId,
                name: name,
                avatarSize: avatarSize,
              ),
        ),
        personAvatarBuilderProvider.overrideWithValue(
          (context, {required accountId, required name, required diameter}) =>
              ChatPersonAvatar(
                accountId: accountId,
                name: name,
                diameter: diameter,
              ),
        ),
      ],
      child: WorkNexusApp(lifecycle: lifecycle),
    ),
  );
}
