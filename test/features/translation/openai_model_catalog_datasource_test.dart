import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/translation/data/datasources/openai_model_catalog_datasource.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);

  final int status;
  final Object body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('lists chat model ids, stripping Gemini\'s models/ prefix', () async {
    final adapter = _Adapter(200, {
      'data': [
        {'id': 'models/gemini-3.8-flash'},
        {'id': 'models/text-embedding-004'},
        {'id': 'models/gemini-3.8-pro'},
      ],
    });
    final source = OpenAiModelCatalogDatasource(
      Dio()..httpClientAdapter = adapter,
    );

    final result = await source.listModels(
      baseUrl: 'https://example.test/v1/',
      apiKey: 'k',
    );

    expect(result.valueOrNull, ['gemini-3.8-flash', 'gemini-3.8-pro']);
    expect(adapter.last?.uri.toString(), 'https://example.test/v1/models');
    expect(adapter.last?.headers['Authorization'], 'Bearer k');
  });

  test('a rejected key comes back as an AuthFailure', () async {
    final source = OpenAiModelCatalogDatasource(
      Dio()..httpClientAdapter = _Adapter(401, {'error': 'bad key'}),
    );

    final result = await source.listModels(
      baseUrl: 'https://x.test',
      apiKey: '',
    );

    expect(result.failureOrNull, isA<AuthFailure>());
  });

  test('an unexpected body is a ParseFailure', () async {
    final source = OpenAiModelCatalogDatasource(
      Dio()..httpClientAdapter = _Adapter(200, {'models': []}),
    );

    final result = await source.listModels(
      baseUrl: 'https://x.test',
      apiKey: '',
    );

    expect(result, isA<Err<List<String>>>());
    expect(result.failureOrNull, isA<ParseFailure>());
  });
}
