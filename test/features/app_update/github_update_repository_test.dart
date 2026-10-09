import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/features/app_update/data/datasources/github_release_datasource.dart';
import 'package:work_nexus/features/app_update/data/datasources/update_installer.dart';
import 'package:work_nexus/features/app_update/data/repositories/github_update_repository.dart';
import 'package:work_nexus/features/app_update/domain/entities/available_update.dart';

class _FakeInstaller extends UpdateInstaller {
  _FakeInstaller({this.writable = true, this.unpackError});

  final bool writable;
  final Object? unpackError;
  String? swapped;

  @override
  String get assetName => 'build.zip';

  @override
  String get installPath => '/apps/WorkNexus';

  @override
  Future<bool> canReplace() async => writable;

  @override
  Future<String> unpack(String zipPath, String directory) async {
    if (unpackError != null) throw unpackError!;
    return directory;
  }

  @override
  Future<void> launchSwap(
    String stagedPath, {
    required String scriptDir,
  }) async {
    swapped = stagedPath;
  }
}

class _FakeReleases extends GitHubReleaseDatasource {
  _FakeReleases(this.content) : super(Dio());

  final String content;

  @override
  Future<void> downloadFile(
    String url,
    String path, {
    void Function(double progress)? onProgress,
  }) async {
    await File(path).writeAsString(content);
    onProgress?.call(1);
  }
}

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('update_repo'));
  tearDown(() => root.deleteSync(recursive: true));

  AvailableUpdate update(String sha) => AvailableUpdate(
    currentVersion: '1.0.0',
    latestVersion: 'v1.1.0',
    releaseUrl: 'https://example.test/release',
    downloadUrl: 'https://example.test/build.zip',
    sha256: sha,
  );

  GitHubUpdateRepository repo(
    _FakeInstaller installer,
    String content, {
    void Function()? quit,
  }) => GitHubUpdateRepository(
    releases: _FakeReleases(content),
    installer: installer,
    stagingRoot: () async => root,
    quit: quit ?? () {},
  );

  test('a download whose checksum matches is unpacked', () async {
    final sha = sha256.convert('build'.codeUnits).toString();
    final result = await repo(_FakeInstaller(), 'build').download(update(sha));

    expect(result.isOk, isTrue);
  });

  test('a download whose checksum differs is refused and removed', () async {
    final result = await repo(
      _FakeInstaller(),
      'tampered',
    ).download(update('0' * 64));

    expect(result.failureOrNull, isA<ParseFailure>());
    expect(root.listSync(), isEmpty);
  });

  test('an unexpected error becomes a failure instead of escaping', () async {
    final sha = sha256.convert('build'.codeUnits).toString();
    final result = await repo(
      _FakeInstaller(unpackError: StateError('boom')),
      'build',
    ).download(update(sha));

    expect(result.failureOrNull, isA<UnexpectedFailure>());
  });

  test('an update with no verified build cannot be downloaded', () async {
    final result = await repo(_FakeInstaller(), 'x').download(
      const AvailableUpdate(
        currentVersion: '1.0.0',
        latestVersion: 'v1.1.0',
        releaseUrl: 'https://example.test/release',
      ),
    );

    expect(result.isErr, isTrue);
  });

  test('install swaps the build in and quits', () async {
    final installer = _FakeInstaller();
    var quit = false;
    final result = await repo(
      installer,
      'x',
      quit: () => quit = true,
    ).install('/staged');

    expect(result.isOk, isTrue);
    expect(installer.swapped, '/staged');
    expect(quit, isTrue);
  });

  test('install reports a read-only location instead of quitting', () async {
    var quit = false;
    final result = await repo(
      _FakeInstaller(writable: false),
      'x',
      quit: () => quit = true,
    ).install('/staged');

    expect(result.failureOrNull, isA<StorageFailure>());
    expect(quit, isFalse);
  });
}
