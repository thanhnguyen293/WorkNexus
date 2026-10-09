import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/app_update/domain/entities/available_update.dart';
import 'package:work_nexus/features/app_update/domain/repositories/update_repository.dart';
import 'package:work_nexus/features/app_update/domain/usecases/check_for_update.dart';
import 'package:work_nexus/features/app_update/presentation/providers/update_provider.dart';
import 'package:work_nexus/features/app_update/presentation/widgets/update_notification_listener.dart';
import 'package:work_nexus/features/app_update/presentation/widgets/update_settings_card.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  testWidgets('shows a notification when a newer stable release is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          updateCheckProvider.overrideWith(
            (ref) async => const Ok(
              AvailableUpdate(
                currentVersion: '1.0.0',
                latestVersion: 'v1.1.0',
                releaseUrl: 'https://github.com/example/WorkNexus/releases',
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppL10n.supportedLocales,
          home: UpdateNotificationListener(child: Scaffold(body: SizedBox())),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('WorkNexus v1.1.0 is available.'), findsOneWidget);
  });

  testWidgets('manual update check reports when the app is up to date', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          updateCheckProvider.overrideWith((ref) async => const Ok(null)),
        ],
        child: MaterialApp(
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.flat,
            density: AppDensity.comfortable,
          ),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const Scaffold(body: UpdateSettingsCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();

    expect(
      find.text("You're using the latest stable version."),
      findsOneWidget,
    );
  });

  group('CheckForUpdate', () {
    test('returns the release when its stable version is newer', () async {
      const useCase = CheckForUpdate(
        _FakeUpdateRepository(
          Ok((
            currentVersion: '1.0.9',
            latestVersion: 'v1.1.0',
            releaseUrl: 'https://github.com/example/WorkNexus/releases',
            downloadUrl: null,
            sha256: null,
          )),
        ),
      );

      final result = await useCase();

      expect(result.valueOrNull?.latestVersion, 'v1.1.0');
    });

    test(
      'does not report an update for the same or an older release',
      () async {
        final sameVersion = await const CheckForUpdate(
          _FakeUpdateRepository(
            Ok((
              currentVersion: '1.2.0',
              latestVersion: 'v1.2.0',
              releaseUrl: 'https://github.com/example/WorkNexus/releases',
              downloadUrl: null,
              sha256: null,
            )),
          ),
        )();
        final olderVersion = await const CheckForUpdate(
          _FakeUpdateRepository(
            Ok((
              currentVersion: '2.0.0',
              latestVersion: 'v1.9.9',
              releaseUrl: 'https://github.com/example/WorkNexus/releases',
              downloadUrl: null,
              sha256: null,
            )),
          ),
        )();

        expect(sameVersion.valueOrNull, isNull);
        expect(olderVersion.valueOrNull, isNull);
      },
    );

    test('a stable release is newer than the installed prerelease', () async {
      final result = await const CheckForUpdate(
        _FakeUpdateRepository(
          Ok((
            currentVersion: '1.2.0-rc.1',
            latestVersion: 'v1.2.0',
            releaseUrl: 'https://github.com/example/WorkNexus/releases',
            downloadUrl: null,
            sha256: null,
          )),
        ),
      )();

      expect(result.valueOrNull?.latestVersion, 'v1.2.0');
    });

    test(
      'skips silently when latest tag has a prerelease suffix but API says stable',
      () async {
        // A maintainer can tag `v1.1.0-alpha.1` and set `prerelease: false`
        // on GitHub. The datasource passes it through; the use case should
        // treat it as "no stable update" — not a hard error.
        final result = await const CheckForUpdate(
          _FakeUpdateRepository(
            Ok((
              currentVersion: '1.0.0',
              latestVersion: 'v1.1.0-alpha.1',
              releaseUrl: 'https://github.com/example/WorkNexus/releases',
              downloadUrl: null,
              sha256: null,
            )),
          ),
        )();

        expect(result.isOk, isTrue);
        expect(result.valueOrNull, isNull);
      },
    );

    test('returns a parse failure for malformed release versions', () async {
      final result = await const CheckForUpdate(
        _FakeUpdateRepository(
          Ok((
            currentVersion: '1.0',
            latestVersion: 'v1.1.0',
            releaseUrl: 'https://github.com/example/WorkNexus/releases',
            downloadUrl: null,
            sha256: null,
          )),
        ),
      )();

      expect(result.isErr, isTrue);
    });
  });
}

class _FakeUpdateRepository implements UpdateRepository {
  const _FakeUpdateRepository(this.result);

  final Result<UpdateVersionSnapshot?> result;

  @override
  Future<Result<UpdateVersionSnapshot?>> fetchLatestStableRelease() async =>
      result;

  @override
  Future<Result<String>> download(
    AvailableUpdate update, {
    void Function(double progress)? onProgress,
  }) async => const Ok('/staged');

  @override
  Future<Result<void>> install(String stagedPath) async => const Ok(null);
}
