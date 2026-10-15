import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/tools/zentao/data/datasources/zentao_language_interceptor.dart';

/// Answers every request with an empty 200, keeping the request it was sent.
class _RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _RecordingAdapter adapter;
  late Dio dio;

  setUp(() {
    adapter = _RecordingAdapter();
    dio = Dio()
      ..httpClientAdapter = adapter
      ..interceptors.add(
        ZenTaoLanguageInterceptor(host: () => 'zentao.example.com'),
      );
  });

  String? cookieOf(int i) => adapter.requests[i].headers['Cookie']?.toString();

  test('asks the ZenTao server for English, beside the session', () async {
    await dio.get<dynamic>(
      'https://zentao.example.com/zentao/bug-assignTo-6492.json',
      options: Options(headers: {'Cookie': 'zentaosid=abc'}),
    );
    await dio.get<dynamic>('https://zentao.example.com/zentao/api.php/v1/bugs');

    expect(cookieOf(0), 'zentaosid=abc; lang=en');
    expect(cookieOf(1), 'lang=en');
  });

  test('other hosts get no cookie', () async {
    await dio.get<dynamic>('https://cdn.example.com/avatar.png');

    expect(cookieOf(0), isNull);
  });

  test("a caller's own lang cookie is kept", () async {
    await dio.get<dynamic>(
      'https://zentao.example.com/zentao/index.html',
      options: Options(headers: {'Cookie': 'zentaosid=abc; lang=zh-cn'}),
    );

    expect(cookieOf(0), 'zentaosid=abc; lang=zh-cn');
  });
}
