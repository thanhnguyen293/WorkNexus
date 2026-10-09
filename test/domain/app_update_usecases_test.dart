import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/app_update/domain/entities/app_release.dart';
import 'package:work_nexus/features/app_update/domain/repositories/update_repository.dart';
import 'package:work_nexus/features/app_update/domain/usecases/check_for_update.dart';
import 'package:work_nexus/features/app_update/domain/usecases/download_update.dart';
import 'package:work_nexus/features/app_update/domain/value_objects/app_version.dart';

class _MockUpdateRepository extends Mock implements UpdateRepository {}

AppRelease _release(String version, {String? sha256 = 'abc'}) => AppRelease(
  version: AppVersion.tryParse(version)!,
  notes: '',
  pageUrl: 'https://example.com/release',
  downloadUrl: 'https://example.com/build.zip',
  sha256: sha256,
);

void main() {
  late _MockUpdateRepository repository;

  setUpAll(() => registerFallbackValue(_release('1.0.0')));
  setUp(() => repository = _MockUpdateRepository());

  group('AppVersion', () {
    test('parses release tags with or without the v prefix', () {
      expect(AppVersion.tryParse('v1.2.3'), const AppVersion(1, 2, 3));
      expect(AppVersion.tryParse('1.2.3'), const AppVersion(1, 2, 3));
    });

    test('rejects tags that are not plain versions', () {
      expect(AppVersion.tryParse('nightly'), isNull);
      expect(AppVersion.tryParse(''), isNull);
      expect(AppVersion.tryParse('v1.2'), isNull);
    });

    test('compares numerically, not as text', () {
      expect(const AppVersion(1, 10, 0) > const AppVersion(1, 9, 9), isTrue);
      expect(const AppVersion(2, 0, 0) > const AppVersion(1, 99, 99), isTrue);
      expect(const AppVersion(1, 0, 1) > const AppVersion(1, 0, 1), isFalse);
    });
  });

  group('CheckForUpdate', () {
    test('offers a newer release', () async {
      final newer = _release('1.1.0');
      when(() => repository.latestRelease()).thenAnswer((_) async => Ok(newer));

      final result = await CheckForUpdate(repository)('v1.0.0');

      expect(result.valueOrNull, newer);
    });

    test('offers nothing when already on the latest or newer', () async {
      when(
        () => repository.latestRelease(),
      ).thenAnswer((_) async => Ok(_release('1.0.0')));

      expect((await CheckForUpdate(repository)('1.0.0')).valueOrNull, isNull);
      expect((await CheckForUpdate(repository)('1.2.0')).valueOrNull, isNull);
    });

    test('never asks for a build without a release version', () async {
      final result = await CheckForUpdate(repository)('');

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, isNull);
      verifyNever(() => repository.latestRelease());
    });

    test('passes a failure through', () async {
      when(
        () => repository.latestRelease(),
      ).thenAnswer((_) async => const Err(NetworkFailure('offline')));

      final result = await CheckForUpdate(repository)('1.0.0');

      expect(result.failureOrNull, isA<NetworkFailure>());
    });
  });

  group('DownloadUpdate', () {
    test('refuses a release without a checksum', () async {
      final result = await DownloadUpdate(repository)(
        _release('1.1.0', sha256: null),
      );

      expect(result.failureOrNull, isA<ParseFailure>());
      verifyNever(() => repository.download(any()));
    });

    test('downloads a release with a checksum', () async {
      when(
        () => repository.download(any(), onProgress: any(named: 'onProgress')),
      ).thenAnswer((_) async => const Ok('/tmp/WorkNexus.app'));

      final result = await DownloadUpdate(repository)(_release('1.1.0'));

      expect(result.valueOrNull, '/tmp/WorkNexus.app');
    });
  });
}
