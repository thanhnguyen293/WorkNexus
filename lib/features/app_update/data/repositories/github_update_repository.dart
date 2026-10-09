import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/debug/app_talker.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/available_update.dart';
import '../../domain/repositories/update_repository.dart';
import '../datasources/github_release_datasource.dart';
import '../datasources/update_installer.dart';

/// Updates from the repository's GitHub Releases: the zip CI attaches for
/// this platform, checked against the release's checksum file.
class GitHubUpdateRepository implements UpdateRepository {
  GitHubUpdateRepository({
    required GitHubReleaseDatasource releases,
    required UpdateInstaller? installer,
    required Future<Directory> Function() stagingRoot,
    void Function()? quit,
  }) : _releases = releases,
       _installer = installer,
       _stagingRoot = stagingRoot,
       _quit = quit ?? (() => exit(0));

  final GitHubReleaseDatasource _releases;

  /// Null on a platform with no in-app install (Linux): updates then only
  /// point at the release page.
  final UpdateInstaller? _installer;
  final Future<Directory> Function() _stagingRoot;
  final void Function() _quit;

  @override
  Future<Result<UpdateVersionSnapshot?>> fetchLatestStableRelease() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final release = await _releases.fetchLatestStableRelease();
      if (release == null) return const Ok(null);

      final assetName = _installer?.assetName;
      final downloadUrl = assetName == null ? null : release.assets[assetName];
      final sumsUrl = release.assets[AppConfig.updateChecksumsAsset];
      final sha256 = assetName == null || downloadUrl == null || sumsUrl == null
          ? null
          : _checksumFor(assetName, await _releases.readText(sumsUrl));

      return Ok((
        currentVersion: packageInfo.version,
        latestVersion: release.tagName,
        releaseUrl: release.htmlUrl,
        // Never offer a download that cannot be verified.
        downloadUrl: sha256 == null ? null : downloadUrl,
        sha256: sha256,
      ));
    } on DioException catch (error, stackTrace) {
      if (error.response?.statusCode == 404) return const Ok(null);
      appTalker.handle(error, stackTrace, 'Update check failed');
      return Err(NetworkFailure('Could not check for updates', cause: error));
    } on FormatException catch (error, stackTrace) {
      appTalker.handle(error, stackTrace, 'Update check response was invalid');
      return Err(
        ParseFailure('Could not read the latest release', cause: error),
      );
    } on PlatformException catch (error, stackTrace) {
      appTalker.handle(error, stackTrace, 'Could not read app version');
      return Err(UnexpectedFailure('Could not read app version', cause: error));
    } catch (error, stackTrace) {
      appTalker.handle(error, stackTrace, 'Update check failed unexpectedly');
      return Err(
        UnexpectedFailure('Could not check for updates', cause: error),
      );
    }
  }

  @override
  Future<Result<String>> download(
    AvailableUpdate update, {
    void Function(double progress)? onProgress,
  }) async {
    final installer = _installer;
    final url = update.downloadUrl;
    final expected = update.sha256;
    if (installer == null || url == null || expected == null) {
      return const Err(UnexpectedFailure('This update cannot be installed'));
    }
    try {
      final root = await _stagingRoot();
      final dir = Directory('${root.path}/${update.latestVersion}');
      // A leftover from an interrupted try would mix two builds.
      if (dir.existsSync()) await dir.delete(recursive: true);
      await dir.create(recursive: true);

      final zip = '${dir.path}/${installer.assetName}';
      await _releases.downloadFile(url, zip, onProgress: onProgress);
      final actual = await _releases.sha256Of(zip);
      if (actual != expected) {
        await dir.delete(recursive: true);
        return Err(
          ParseFailure(
            'Checksum mismatch for ${update.latestVersion}: '
            'expected $expected, got $actual',
          ),
        );
      }
      final unpacked = Directory('${dir.path}/build');
      await unpacked.create();
      return Ok(await installer.unpack(zip, unpacked.path));
    } on DioException catch (e) {
      return Err(NetworkFailure('Downloading the update failed', cause: e));
    } on IOException catch (e) {
      // Includes a failed unpack (ProcessException).
      return Err(StorageFailure('Preparing the update failed', cause: e));
    }
  }

  @override
  Future<Result<void>> install(String stagedPath) async {
    final installer = _installer;
    if (installer == null) {
      return const Err(UnexpectedFailure('This update cannot be installed'));
    }
    if (!await installer.canReplace()) {
      return Err(
        StorageFailure(
          'No write access to ${Directory(installer.installPath).parent.path}',
        ),
      );
    }
    try {
      await installer.launchSwap(
        stagedPath,
        scriptDir: (await _stagingRoot()).path,
      );
    } on IOException catch (e) {
      return Err(StorageFailure('Starting the installer failed', cause: e));
    }
    _quit();
    return const Ok(null);
  }

  /// The hash on the `<sha256>  <name>` line for [asset], as `sha256sum`
  /// writes it; null when the file does not list it.
  static String? _checksumFor(String asset, String sums) {
    for (final line in sums.split('\n')) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length != 2) continue;
      if (parts[1].replaceFirst('*', '') == asset) {
        return parts[0].toLowerCase();
      }
    }
    return null;
  }
}
