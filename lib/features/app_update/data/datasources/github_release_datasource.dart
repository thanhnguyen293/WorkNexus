import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../models/github_release_dto.dart';

/// Reads releases of the public WorkNexus repository and downloads their
/// assets. No token: the unauthenticated rate limit (60/hour) is plenty for a
/// check every few hours.
class GithubReleaseDatasource {
  GithubReleaseDatasource({Dio? dio, this.repository = defaultRepository})
    : _dio = dio ?? Dio() {
    _dio.options
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(minutes: 5)
      ..headers['Accept'] = 'application/vnd.github+json';
  }

  static const defaultRepository = 'thanhnguyen293/WorkNexus';

  final Dio _dio;

  /// `owner/name`.
  final String repository;

  /// The newest published, non-prerelease release (so never `nightly`).
  Future<GithubReleaseDto> latest() async {
    final response = await _dio.get<Map<String, dynamic>>(
      'https://api.github.com/repos/$repository/releases/latest',
    );
    return GithubReleaseDto.fromJson(response.data ?? const {});
  }

  Future<String> readText(String url) async {
    final response = await _dio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );
    return response.data ?? '';
  }

  Future<void> downloadFile(
    String url,
    String path, {
    void Function(double progress)? onProgress,
  }) => _dio.download(
    url,
    path,
    onReceiveProgress: (received, total) {
      if (total > 0) onProgress?.call(received / total);
    },
  );

  /// Lower-case hex SHA-256 of the file at [path], streamed.
  Future<String> sha256Of(String path) async =>
      (await sha256.bind(File(path).openRead()).first).toString();
}
