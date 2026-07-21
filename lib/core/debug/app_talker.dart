import 'package:dio/dio.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';
import 'package:talker_flutter/talker_flutter.dart';

// Cap the in-memory log history: talker keeps the full [Response] (body and
// all) for every entry, so an unbounded 1000-item default retains up to 1000
// response bodies for the app's whole lifetime.
final appTalker = Talker(
  settings: TalkerSettings(useConsoleLogs: false, maxHistoryItems: 200),
);

TalkerDioLogger buildTalkerDioLogger() => TalkerDioLogger(
  talker: appTalker,
  settings: TalkerDioLoggerSettings(
    printRequestData: false,
    // Never format response bodies. The default (true) JSON-encodes every
    // response — including a Uint8List image byte-for-byte — synchronously on
    // the UI isolate, ballooning memory and freezing the app.
    printResponseData: false,
    printResponseTime: true,
    requestFilter: _isLoggable,
    responseFilter: (response) => _isLoggable(response.requestOptions),
    errorFilter: (error) => _isLoggable(error.requestOptions),
  ),
);

/// Whether a request should be logged at all. Excludes auth-token requests
/// (secrets) and binary byte fetches — inline images and downloads — whose
/// multi-MB [Response.data] would otherwise be retained in talker's history.
bool _isLoggable(RequestOptions options) =>
    !options.path.endsWith('/tokens') &&
    options.responseType != ResponseType.bytes;
