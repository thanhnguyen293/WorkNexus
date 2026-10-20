import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/app_update/domain/entities/available_update.dart';
import 'package:work_nexus/features/app_update/domain/repositories/update_repository.dart';
import 'package:work_nexus/features/app_update/domain/usecases/check_for_update.dart';
import 'package:work_nexus/features/app_update/domain/usecases/download_update.dart';
import 'package:work_nexus/features/app_update/domain/usecases/install_update.dart';
import 'package:work_nexus/features/app_update/presentation/providers/update_controller.dart';
import 'package:work_nexus/features/app_update/presentation/providers/update_state.dart';

class _MockUpdateRepository extends Mock implements UpdateRepository {}

const _release = (
  currentVersion: '1.0.0',
  latestVersion: 'v1.1.0',
  releaseUrl: 'https://github.com/example/WorkNexus/releases',
  releaseNotes: '',
  downloadUrl: 'https://example.com/WorkNexus.zip',
  sha256: 'abc',
);

/// Lets the download the check started in the background finish.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _MockUpdateRepository repository;

  setUpAll(() {
    registerFallbackValue(
      const AvailableUpdate(
        currentVersion: '',
        latestVersion: '',
        releaseUrl: '',
      ),
    );
  });

  setUp(() {
    repository = _MockUpdateRepository();
    when(
      () => repository.fetchLatestStableRelease(),
    ).thenAnswer((_) async => const Ok(_release));
    when(
      () => repository.download(any(), onProgress: any(named: 'onProgress')),
    ).thenAnswer((_) async => const Ok('/staged/v1.1.0'));
    when(
      () => repository.install(any()),
    ).thenAnswer((_) async => const Ok(null));
  });

  ProviderContainer makeContainer({
    Duration checkEvery = const Duration(hours: 1),
    Future<bool> Function()? autoUpdateEnabled,
  }) {
    final container = ProviderContainer(
      overrides: [
        updateControllerProvider.overrideWith(
          () => UpdateController(
            checkForUpdate: CheckForUpdate(repository),
            downloadUpdate: DownloadUpdate(repository),
            installUpdate: InstallUpdate(repository),
            checkEvery: checkEvery,
            autoUpdateEnabled: autoUpdateEnabled,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'checks on its own when it starts and downloads what it finds',
    () async {
      final container = makeContainer();

      container.read(updateControllerProvider);
      await _settle();

      verify(() => repository.fetchLatestStableRelease()).called(1);
      expect(
        container.read(updateControllerProvider),
        isA<UpdateReady>().having(
          (s) => s.stagedPath,
          'stagedPath',
          '/staged/v1.1.0',
        ),
      );
      verifyNever(() => repository.install(any()));
    },
  );

  test('a manual check shares the one already running', () async {
    // The lookup takes a moment, as a real one does, so the check the
    // controller starts on its own meets the manual one still in flight.
    when(() => repository.fetchLatestStableRelease()).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return const Ok(_release);
    });
    final container = makeContainer();
    final notifier = container.read(updateControllerProvider.notifier);

    final result = await notifier.check();
    await _settle();

    expect(result.valueOrNull?.latestVersion, 'v1.1.0');
    verify(() => repository.fetchLatestStableRelease()).called(1);
    verify(
      () => repository.download(any(), onProgress: any(named: 'onProgress')),
    ).called(1);
  });

  test('installs the staged build only when the user restarts', () async {
    final container = makeContainer();
    final notifier = container.read(updateControllerProvider.notifier);
    container.read(updateControllerProvider);
    await _settle();

    await notifier.installAndRestart();

    verify(() => repository.install('/staged/v1.1.0')).called(1);
    expect(container.read(updateControllerProvider), isA<UpdateInstalling>());
  });

  test(
    'a release without a build for this platform waits for the user',
    () async {
      when(() => repository.fetchLatestStableRelease()).thenAnswer(
        (_) async => const Ok((
          currentVersion: '1.0.0',
          latestVersion: 'v1.1.0',
          releaseUrl: 'https://github.com/example/WorkNexus/releases',
          releaseNotes: '',
          downloadUrl: null,
          sha256: null,
        )),
      );
      final container = makeContainer();

      container.read(updateControllerProvider);
      await _settle();

      expect(container.read(updateControllerProvider), isA<UpdateManual>());
      verifyNever(
        () => repository.download(any(), onProgress: any(named: 'onProgress')),
      );
    },
  );

  test('a failed download is reported and retried by the next check', () async {
    var attempts = 0;
    when(
      () => repository.download(any(), onProgress: any(named: 'onProgress')),
    ).thenAnswer((_) async {
      attempts++;
      if (attempts == 1) return const Err(NetworkFailure('offline'));
      return const Ok('/staged/v1.1.0');
    });
    final container = makeContainer();
    final notifier = container.read(updateControllerProvider.notifier);
    container.read(updateControllerProvider);
    await _settle();
    expect(container.read(updateControllerProvider), isA<UpdateFailed>());

    await notifier.check();
    await _settle();

    expect(container.read(updateControllerProvider), isA<UpdateReady>());
  });

  test('a check that fails leaves the state alone', () async {
    when(
      () => repository.fetchLatestStableRelease(),
    ).thenAnswer((_) async => const Err(NetworkFailure('offline')));
    final container = makeContainer();

    final result = await container
        .read(updateControllerProvider.notifier)
        .check();
    await _settle();

    expect(result.isErr, isTrue);
    expect(container.read(updateControllerProvider), isA<UpdateIdle>());
  });

  test('a release already staged is not downloaded again', () async {
    final container = makeContainer();
    final notifier = container.read(updateControllerProvider.notifier);
    container.read(updateControllerProvider);
    await _settle();

    await notifier.check();
    await _settle();

    verify(() => repository.fetchLatestStableRelease()).called(2);
    verify(
      () => repository.download(any(), onProgress: any(named: 'onProgress')),
    ).called(1);
  });

  testWidgets('checks again every hour', (tester) async {
    final container = makeContainer();
    container.read(updateControllerProvider);
    await tester.pump();
    verify(() => repository.fetchLatestStableRelease()).called(1);

    await tester.pump(const Duration(hours: 1));
    verify(() => repository.fetchLatestStableRelease()).called(1);

    await tester.pump(const Duration(hours: 1));
    verify(() => repository.fetchLatestStableRelease()).called(1);

    // The periodic timer must be gone before the test binding checks for it.
    container.dispose();
  });

  group('with automatic updates off', () {
    test('it neither checks nor downloads on its own', () async {
      final container = makeContainer(
        checkEvery: const Duration(milliseconds: 5),
        autoUpdateEnabled: () async => false,
      );

      container.read(updateControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(container.read(updateControllerProvider), isA<UpdateIdle>());
      verifyNever(() => repository.fetchLatestStableRelease());
      verifyNever(
        () => repository.download(any(), onProgress: any(named: 'onProgress')),
      );
    });

    test(
      'turned off while a background check runs, nothing downloads',
      () async {
        when(() => repository.fetchLatestStableRelease()).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return const Ok(_release);
        });
        var enabled = true;
        final container = makeContainer(autoUpdateEnabled: () async => enabled);

        container.read(updateControllerProvider);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        enabled = false;
        await Future<void>.delayed(const Duration(milliseconds: 40));

        verify(() => repository.fetchLatestStableRelease()).called(1);
        verifyNever(
          () =>
              repository.download(any(), onProgress: any(named: 'onProgress')),
        );
        expect(container.read(updateControllerProvider), isA<UpdateIdle>());
      },
    );

    test('a check the user asks for still looks', () async {
      final container = makeContainer(autoUpdateEnabled: () async => false);

      final result = await container
          .read(updateControllerProvider.notifier)
          .check();

      expect(result, isA<Ok<AvailableUpdate?>>());
      verify(() => repository.fetchLatestStableRelease()).called(1);
    });
  });
}
