import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/error/failure.dart';
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
    test('lists the notes of every release since the running one', () async {
      const useCase = CheckForUpdate(
        _FakeUpdateRepository(
          Ok((
            currentVersion: '1.0.0',
            latestVersion: 'v1.2.0',
            releaseUrl: 'https://github.com/example/WorkNexus/releases',
            releaseNotes: '- Latest only',
            downloadUrl: null,
            sha256: null,
          )),
          notes: Ok([
            (version: 'v1.0.0', notes: '- Already running'),
            (version: 'v1.1.0', notes: '- Middle'),
            (version: 'v1.2.0', notes: '- Latest'),
          ]),
        ),
      );

      final notes = (await useCase()).valueOrNull?.releaseNotes;

      expect(notes, '## v1.2.0\n\n- Latest\n\n## v1.1.0\n\n- Middle');
    });

    test('keeps the latest notes when the others cannot be read', () async {
      const useCase = CheckForUpdate(
        _FakeUpdateRepository(
          Ok((
            currentVersion: '1.0.0',
            latestVersion: 'v1.2.0',
            releaseUrl: 'https://github.com/example/WorkNexus/releases',
            releaseNotes: '- Latest only',
            downloadUrl: null,
            sha256: null,
          )),
          notes: Err(NetworkFailure('offline')),
        ),
      );

      expect((await useCase()).valueOrNull?.releaseNotes, '- Latest only');
    });

    test('returns the release when its stable version is newer', () async {
      const useCase = CheckForUpdate(
        _FakeUpdateRepository(
          Ok((
            currentVersion: '1.0.9',
            latestVersion: 'v1.1.0',
            releaseUrl: 'https://github.com/example/WorkNexus/releases',
            releaseNotes: '- Faster sync',
            downloadUrl: null,
            sha256: null,
          )),
        ),
      );

      final result = await useCase();

      expect(result.valueOrNull?.latestVersion, 'v1.1.0');
      expect(result.valueOrNull?.releaseNotes, '- Faster sync');
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
              releaseNotes: '',
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
              releaseNotes: '',
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
            releaseNotes: '',
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
              releaseNotes: '',
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
            releaseNotes: '',
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
  const _FakeUpdateRepository(this.result, {this.notes = const Ok([])});

  final Result<UpdateVersionSnapshot?> result;
  final Result<List<ReleaseNote>> notes;

  @override
  Future<Result<List<ReleaseNote>>> fetchStableReleaseNotes() async => notes;

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
