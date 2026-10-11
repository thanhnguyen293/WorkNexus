import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';

typedef GitHubRelease = ({
  String tagName,
  String htmlUrl,

  /// The release description (GitHub Markdown); empty when there is none.
  String notes,

  /// Asset name → browser download URL.
  Map<String, String> assets,
});

class GitHubReleaseDatasource {
  GitHubReleaseDatasource(this._dio);

  static const _latestReleaseUrl =
      'https://api.github.com/repos/${AppConfig.githubOwner}/${AppConfig.githubRepo}/releases/latest';

  final Dio _dio;

  Future<GitHubRelease?> fetchLatestStableRelease() async {
    final response = await _dio.get<Object?>(
      _latestReleaseUrl,
      options: Options(
        headers: const {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'User-Agent': AppConfig.appName,
        },
      ),
    );
    final body = response.data;
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Invalid GitHub release response');
    }

    final tagName = body['tag_name'];
    final htmlUrl = body['html_url'];
    if (tagName is! String ||
        htmlUrl is! String ||
        body['draft'] != false ||
        body['prerelease'] != false) {
      throw const FormatException('GitHub did not return a stable release');
    }
    final assets = <String, String>{};
    if (body['assets'] case final List<Object?> list) {
      for (final asset in list) {
        if (asset is! Map<String, dynamic>) continue;
        final name = asset['name'];
        final url = asset['browser_download_url'];
        if (name is String && url is String) assets[name] = url;
      }
    }
    final notes = body['body'];
    return (
      tagName: tagName,
      htmlUrl: htmlUrl,
      notes: notes is String ? notes.trim() : '',
      assets: assets,
    );
  }

  Future<String> readText(String url) async {
    final response = await _dio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );
    return response.data ?? '';
  }

  /// Streams [url] to [path]; the long timeout is the download's, not the
  /// API's.
  Future<void> downloadFile(
    String url,
    String path, {
    void Function(double progress)? onProgress,
  }) async {
    await _dio.download(
      url,
      path,
      options: Options(receiveTimeout: const Duration(minutes: 10)),
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress?.call(received / total);
      },
    );
  }

  Future<String> sha256Of(String path) async =>
      (await sha256.bind(File(path).openRead()).first).toString();
}
