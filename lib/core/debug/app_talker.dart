import 'package:dio/dio.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';
import 'package:talker_flutter/talker_flutter.dart';

final appTalker = Talker(settings: TalkerSettings(useConsoleLogs: false));

TalkerDioLogger buildTalkerDioLogger() => TalkerDioLogger(
  talker: appTalker,
  settings: TalkerDioLoggerSettings(
    printRequestData: false,
    printResponseTime: true,
    requestFilter: _isNotTokenRequest,
    responseFilter: (response) => _isNotTokenRequest(response.requestOptions),
    errorFilter: (error) => _isNotTokenRequest(error.requestOptions),
  ),
);

bool _isNotTokenRequest(RequestOptions options) =>
    !options.path.endsWith('/tokens');
