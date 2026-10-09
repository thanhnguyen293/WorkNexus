import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/features/app_update/data/datasources/github_release_datasource.dart';
import 'package:work_nexus/features/app_update/data/datasources/update_installer.dart';
import 'package:work_nexus/features/app_update/data/mappers/github_release_mapper.dart';
import 'package:work_nexus/features/app_update/data/models/github_release_dto.dart';
import 'package:work_nexus/features/app_update/data/repositories/github_update_repository.dart';
import 'package:work_nexus/features/app_update/domain/value_objects/app_version.dart';

class _MockReleases extends Mock implements GithubReleaseDatasource {}

class _MockInstaller extends Mock implements UpdateInstaller {}

const _asset = 'work_nexus-macos.zip';
const _hash =
    '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08';

const _dto = GithubReleaseDto(
  tagName: 'v1.4.0',
  body: '## Features',
  htmlUrl: 'https://github.com/o/r/releases/tag/v1.4.0',
  assets: {
    _asset: 'https://example.com/mac.zip',
    'worknexus-windows.zip': 'https://example.com/win.zip',
    checksumAssetName: 'https://example.com/sums',
  },
);

void main() {
  late _MockReleases releases;
  late _MockInstaller installer;
  late Directory staging;
  late GithubUpdateRepository repository;
  var quits = 0;

  setUp(() {
    releases = _MockReleases();
    installer = _MockInstaller();
    staging = Directory.systemTemp.createTempSync('update_test');
    quits = 0;
    when(() => installer.assetName).thenReturn(_asset);
    when(() => installer.installPath).thenReturn('/Applications/WorkNexus.app');
    repository = GithubUpdateRepository(
      releases: releases,
      installer: installer,
      stagingRoot: () async => staging,
      quit: () => quits++,
    );
  });

  tearDown(() => staging.deleteSync(recursive: true));

  group('checksumFor', () {
    test('finds the hash for a file, in text or binary mode', () {
      final sums =
          '$_hash  $_asset\n'
          '${'0' * 64} *worknexus-windows.zip\n';
      expect(checksumFor(sums, _asset), _hash);
      expect(checksumFor(sums, 'worknexus-windows.zip'), '0' * 64);
      expect(checksumFor(sums, 'missing.zip'), isNull);
    });
  });

  test('latestRelease picks this platform\'s build and its checksum', () async {
    when(() => releases.latest()).thenAnswer((_) async => _dto);
    when(
      () => releases.readText('https://example.com/sums'),
    ).thenAnswer((_) async => '$_hash  $_asset\n');

    final release = (await repository.latestRelease()).valueOrNull!;

    expect(release.version, const AppVersion(1, 4, 0));
    expect(release.downloadUrl, 'https://example.com/mac.zip');
    expect(release.sha256, _hash);
  });

  test('a release without this platform\'s build offers nothing', () async {
    when(() => releases.latest()).thenAnswer(
      (_) async => const GithubReleaseDto(
        tagName: 'v1.4.0',
        body: '',
        htmlUrl: '',
        assets: {'worknexus-windows.zip': 'https://example.com/win.zip'},
      ),
    );

    final result = await repository.latestRelease();

    expect(result.isOk, isTrue);
    expect(result.valueOrNull, isNull);
  });

  test('download rejects a build whose hash does not match', () async {
    when(() => releases.latest()).thenAnswer((_) async => _dto);
    when(
      () => releases.readText(any()),
    ).thenAnswer((_) async => '$_hash  $_asset\n');
    final release = (await repository.latestRelease()).valueOrNull!;
    when(
      () => releases.downloadFile(
        any(),
        any(),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((_) async {});
    when(() => releases.sha256Of(any())).thenAnswer((_) async => '1' * 64);

    final result = await repository.download(release);

    expect(result.failureOrNull, isA<ParseFailure>());
    verifyNever(() => installer.unpack(any(), any()));
    expect(Directory('${staging.path}/1.4.0').existsSync(), isFalse);
  });

  test('install without write access neither swaps nor quits', () async {
    when(() => installer.canReplace()).thenAnswer((_) async => false);

    final result = await repository.install('/tmp/new/WorkNexus.app');

    expect(result.failureOrNull, isA<StorageFailure>());
    verifyNever(
      () => installer.launchSwap(any(), scriptDir: any(named: 'scriptDir')),
    );
    expect(quits, 0);
  });

  test('install starts the swap, then quits', () async {
    when(() => installer.canReplace()).thenAnswer((_) async => true);
    when(
      () => installer.launchSwap(any(), scriptDir: any(named: 'scriptDir')),
    ).thenAnswer((_) async {});

    final result = await repository.install('/tmp/new/WorkNexus.app');

    expect(result.isOk, isTrue);
    verify(
      () => installer.launchSwap(
        '/tmp/new/WorkNexus.app',
        scriptDir: staging.path,
      ),
    ).called(1);
    expect(quits, 1);
  });
}
