import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/app_update/domain/entities/available_update.dart';
import 'package:work_nexus/features/app_update/domain/repositories/update_repository.dart';
import 'package:work_nexus/features/app_update/domain/usecases/build_issue_report_url.dart';
import 'package:work_nexus/features/app_update/domain/usecases/check_for_update.dart';

void main() {
  test(
    'the issue link targets this builds repository with version filled in',
    () {
      final url = const BuildIssueReportUrl()(
        appVersion: '1.4.1',
        system: 'Windows 11',
      );

      expect(url.host, 'github.com');
      expect(url.path, '/thanhnguyen293/WorkNexus/issues/new');
      expect(url.queryParameters['body'], contains('WorkNexus 1.4.1'));
      expect(url.queryParameters['body'], contains('System: Windows 11'));
    },
  );

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
  Future<String> currentVersion() async => '1.0.0';

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
