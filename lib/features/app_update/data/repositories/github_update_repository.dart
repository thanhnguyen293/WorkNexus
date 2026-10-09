import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/app_release.dart';
import '../../domain/repositories/update_repository.dart';
import '../datasources/github_release_datasource.dart';
import '../datasources/update_installer.dart';
import '../mappers/github_release_mapper.dart';

/// Updates from the repository's GitHub Releases: the zip CI attaches for
/// this platform, checked against the release's `SHA256SUMS.txt`.
class GithubUpdateRepository implements UpdateRepository {
  GithubUpdateRepository({
    required GithubReleaseDatasource releases,
    required UpdateInstaller installer,
    required Future<Directory> Function() stagingRoot,
    void Function()? quit,
  }) : _releases = releases,
       _installer = installer,
       _stagingRoot = stagingRoot,
       _quit = quit ?? (() => exit(0));

  final GithubReleaseDatasource _releases;
  final UpdateInstaller _installer;
  final Future<Directory> Function() _stagingRoot;
  final void Function() _quit;

  @override
  Future<Result<AppRelease?>> latestRelease() async {
    try {
      final dto = await _releases.latest();
      final sumsUrl = dto.assets[checksumAssetName];
      final sums = sumsUrl == null ? null : await _releases.readText(sumsUrl);
      return Ok(
        releaseFromDto(dto, assetName: _installer.assetName, checksums: sums),
      );
    } on DioException catch (e) {
      // A repository with no stable release yet answers 404.
      if (e.response?.statusCode == 404) return const Ok(null);
      return Err(NetworkFailure('Checking for updates failed', cause: e));
    } on Exception catch (e) {
      return Err(ParseFailure('Unreadable release', cause: e));
    }
  }

  @override
  Future<Result<String>> download(
    AppRelease release, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final root = await _stagingRoot();
      final dir = Directory('${root.path}/${release.version}');
      // A leftover from an interrupted try would mix two builds.
      if (dir.existsSync()) await dir.delete(recursive: true);
      await dir.create(recursive: true);

      final zip = '${dir.path}/${_installer.assetName}';
      await _releases.downloadFile(
        release.downloadUrl,
        zip,
        onProgress: onProgress,
      );
      final actual = await _releases.sha256Of(zip);
      if (actual != release.sha256) {
        await dir.delete(recursive: true);
        return Err(
          ParseFailure(
            'Checksum mismatch for ${release.version}: '
            'expected ${release.sha256}, got $actual',
          ),
        );
      }
      final unpacked = Directory('${dir.path}/build');
      await unpacked.create();
      return Ok(await _installer.unpack(zip, unpacked.path));
    } on DioException catch (e) {
      return Err(NetworkFailure('Downloading the update failed', cause: e));
    } on IOException catch (e) {
      // Includes a failed unpack (ProcessException).
      return Err(StorageFailure('Preparing the update failed', cause: e));
    }
  }

  @override
  Future<Result<void>> install(String stagedPath) async {
    if (!await _installer.canReplace()) {
      return Err(
        StorageFailure(
          'No write access to ${Directory(_installer.installPath).parent.path}',
        ),
      );
    }
    try {
      await _installer.launchSwap(
        stagedPath,
        scriptDir: (await _stagingRoot()).path,
      );
    } on IOException catch (e) {
      return Err(StorageFailure('Starting the installer failed', cause: e));
    }
    _quit();
    return const Ok(null);
  }
}
