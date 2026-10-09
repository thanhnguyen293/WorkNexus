import 'package:dio/dio.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';
import 'package:talker_flutter/talker_flutter.dart';

// Cap the in-memory log history: talker keeps the full [Response] (body and
// all) for every entry, so an unbounded 1000-item default retains up to 1000
// response bodies for the app's whole lifetime.
final appTalker = Talker(
  settings: TalkerSettings(useConsoleLogs: false, maxHistoryItems: 200),
);

TalkerDioLogger buildTalkerDioLogger() => _AppDioLogger(appTalker);

/// [TalkerDioLogger] logs each request's raw URI, so a URL carrying a secret —
/// ZenTao's classic channel puts the session id in `?zentaosid=` — would land
/// in the in-app log, which can be copied and shared. Such requests are kept
/// out of it and logged here as one line, with the secret masked.
class _AppDioLogger extends TalkerDioLogger {
  _AppDioLogger(this._log)
    : super(
        talker: _log,
        settings: TalkerDioLoggerSettings(
          printRequestData: false,
          // Never format response bodies. The default (true) JSON-encodes every
          // response — including a Uint8List image byte-for-byte — synchronously
          // on the UI isolate, ballooning memory and freezing the app.
          printResponseData: false,
          printResponseTime: true,
          requestFilter: _isLoggable,
          responseFilter: (response) => _isLoggable(response.requestOptions),
          errorFilter: (error) => _isLoggable(error.requestOptions),
        ),
      );

  final Talker _log;

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _logMasked(response.requestOptions, response.statusCode);
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logMasked(err.requestOptions, err.response?.statusCode, error: err.type);
    super.onError(err, handler);
  }

  void _logMasked(
    RequestOptions options,
    int? status, {
    DioExceptionType? error,
  }) {
    if (!_carriesSecret(options) || _isExcluded(options)) return;
    final line =
        '${options.method} ${maskUrlSecrets(options.uri)} -> '
        '${status ?? error?.name ?? '?'}';
    error == null ? _log.info(line) : _log.warning(line);
  }
}

/// Query parameter names that hold a credential or session id: `zentaosid`,
/// `private_token`, `api_key`… (but not `keywords` or `side`).
final _secretParam = RegExp(
  r'(sid|token|password|passwd|secret|key)$',
  caseSensitive: false,
);

/// [uri] with the values of secret-looking query parameters replaced by `***`.
Uri maskUrlSecrets(Uri uri) => _hasSecret(uri)
    ? uri.replace(
        // Built by hand: `queryParameters:` would percent-encode the `***`.
        query: [
          for (final MapEntry(:key, :value) in uri.queryParameters.entries)
            '${Uri.encodeQueryComponent(key)}='
                '${_secretParam.hasMatch(key) ? '***' : Uri.encodeQueryComponent(value)}',
        ].join('&'),
      )
    : uri;

bool _hasSecret(Uri uri) => uri.queryParameters.keys.any(_secretParam.hasMatch);

bool _carriesSecret(RequestOptions options) => _hasSecret(options.uri);

/// Never logged at all: auth-token requests (secrets) and binary byte fetches —
/// inline images and downloads — whose multi-MB [Response.data] would otherwise
/// be retained in talker's history.
bool _isExcluded(RequestOptions options) =>
    options.path.endsWith('/tokens') ||
    options.responseType == ResponseType.bytes;

/// Whether [TalkerDioLogger] may log a request: not excluded, and no secret in
/// its URL (those are logged masked by [_AppDioLogger] instead).
bool _isLoggable(RequestOptions options) =>
    !_isExcluded(options) && !_carriesSecret(options);
