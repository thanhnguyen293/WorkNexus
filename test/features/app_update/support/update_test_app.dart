import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/app_update/domain/entities/available_update.dart';
import 'package:work_nexus/features/app_update/domain/repositories/update_repository.dart';
import 'package:work_nexus/features/app_update/domain/usecases/check_for_update.dart';
import 'package:work_nexus/features/app_update/domain/usecases/download_update.dart';
import 'package:work_nexus/features/app_update/domain/usecases/install_update.dart';
import 'package:work_nexus/features/app_update/presentation/providers/update_controller.dart';
import 'package:work_nexus/features/app_update/presentation/providers/update_provider.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

class MockUpdateRepository extends Mock implements UpdateRepository {}

const updateReleaseUrl = 'https://github.com/example/WorkNexus/releases';

/// A newer release that only the release page offers (no build to download).
const manualRelease = (
  currentVersion: '1.0.0',
  latestVersion: 'v1.1.0',
  releaseUrl: updateReleaseUrl,
  downloadUrl: null,
  sha256: null,
);

/// A newer release with a verified build for this platform.
const installableRelease = (
  currentVersion: '1.0.0',
  latestVersion: 'v1.1.0',
  releaseUrl: updateReleaseUrl,
  downloadUrl: 'https://example.com/WorkNexus.zip',
  sha256: 'abc',
);

/// A repository whose download and install succeed; stub the release per test.
MockUpdateRepository mockUpdateRepository() {
  registerFallbackValue(
    const AvailableUpdate(
      currentVersion: '',
      latestVersion: '',
      releaseUrl: '',
    ),
  );
  final repository = MockUpdateRepository();
  when(
    () => repository.download(any(), onProgress: any(named: 'onProgress')),
  ).thenAnswer((_) async => const Ok('/staged'));
  when(() => repository.install(any())).thenAnswer((_) async => const Ok(null));
  return repository;
}

/// [home] under a themed, localized app whose update controller runs on
/// [repository] and reports version 1.4.1.
Widget updateTestApp({
  required UpdateRepository repository,
  required Widget home,
}) {
  return ProviderScope(
    overrides: [
      updateControllerProvider.overrideWith(
        () => UpdateController(
          checkForUpdate: CheckForUpdate(repository),
          downloadUpdate: DownloadUpdate(repository),
          installUpdate: InstallUpdate(repository),
        ),
      ),
      appVersionProvider.overrideWith((ref) async => '1.4.1'),
    ],
    child: MaterialApp(
      theme: buildAppTheme(
        variant: AppThemeVariant.light,
        surface: SurfaceStyle.flat,
        density: AppDensity.comfortable,
      ),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: home,
    ),
  );
}
