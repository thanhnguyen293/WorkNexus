import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../../../../core/debug/app_talker.dart';
import '../../../../core/network/api_paging.dart';
import 'gitlab_models.dart';

part 'gitlab_client_reads.dart';
part 'gitlab_client_sub_resources.dart';
part 'gitlab_client_mutations.dart';
part 'gitlab_client_assets.dart';

/// HTTP transport for the GitLab REST v4 API, bound to one account's base URL +
/// Personal Access Token (PAT). The PAT is a static credential attached as the
/// `PRIVATE-TOKEN` header by an interceptor — but only for requests to the
/// instance host, so it is never leaked to a third-party host (e.g. an external
/// image URL fetched by [fetchBytes]).
///
/// List endpoints return a bare JSON array; [_paginate] walks pages via the
/// `X-Next-Page` response header. `validateStatus` is left at dio's default
/// (throw on non-2xx) so the adapter's `_guard` can classify 401/403/404.
class GitLabClient extends _GitLabClientBase
    with _GitLabReads, _GitLabSubResources, _GitLabMutations, _GitLabAssets {
  GitLabClient({required super.baseUrl, required super.token, super.dio});
}

/// The configured [Dio] (base URL, timeouts, TLS policy, host-scoped PAT
/// interceptor) and the pagination / response helpers every part of
/// [GitLabClient] shares.
abstract class _GitLabClientBase {
  _GitLabClientBase({required String baseUrl, required this.token, Dio? dio})
    : baseUrl = _normalizeBase(baseUrl),
      _host = Uri.parse(_normalizeBase(baseUrl)).host,
      _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = '${_normalizeBase(baseUrl)}/api/v4'
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 30);
    // Self-hosted GitLab may use a self-signed / untrusted TLS cert. Accept it
    // for the user's own server, but keep normal validation for gitlab.com so a
    // bad cert there is never silently trusted. Only when we own the Dio instance
    // (tests inject their own adapter).
    if (dio == null) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (cert, host, port) =>
              host != 'gitlab.com';
          return client;
        },
      );
    }
    // Attach the PAT only to instance-host requests — never send it to a
    // third-party host (an absolute image URL in a description would otherwise
    // leak the token).
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.uri.host == _host) {
            options.headers['PRIVATE-TOKEN'] = token;
          }
          handler.next(options);
        },
      ),
    );
    _dio.interceptors.add(buildTalkerDioLogger());
  }

  final String baseUrl;
  final String token;
  final String _host;
  final Dio _dio;

  static String _normalizeBase(String url) {
    var u = url.trim();
    if (u.isEmpty) return u;
    if (!u.startsWith('http')) u = 'https://$u';
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    // Tolerate a pasted API base — keep the web root.
    if (u.endsWith('/api/v4')) u = u.substring(0, u.length - '/api/v4'.length);
    return u;
  }

  // ---- helpers ----

  /// Walks a paginated list endpoint via the `X-Next-Page` header, accumulating
  /// typed items. Stops when the header is empty or doesn't advance (defensive
  /// against a server that ignores `page`), capped at [maxPages].
  Future<List<T>> _paginate<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson, {
    Map<String, dynamic>? query,
    int maxPages = 20,
  }) async {
    final out = <T>[];
    var page = 1;
    for (var i = 0; i < maxPages; i++) {
      final res = await _dio.get<dynamic>(
        path,
        queryParameters: {
          'per_page': kDefaultApiPageLimit,
          'page': page,
          ...?query,
        },
      );
      final data = res.data;
      if (data is List) {
        for (final e in data) {
          if (e is Map) out.add(fromJson(Map<String, dynamic>.from(e)));
        }
      }
      final next = res.headers.value('x-next-page');
      final parsed = next == null || next.isEmpty ? null : int.tryParse(next);
      if (parsed == null || parsed <= page) break;
      page = parsed;
    }
    return out;
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    throw DioException(
      requestOptions: RequestOptions(path: _dio.options.baseUrl),
      message: 'GitLab response was not a JSON object',
    );
  }
}
