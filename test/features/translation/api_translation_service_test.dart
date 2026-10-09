import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/domain/entities/translation_record.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/translation/data/api_translation_service.dart';
import 'package:work_nexus/features/translation/data/routing_translation_service.dart';
import 'package:work_nexus/features/translation/domain/adapters/translation_service.dart';
import 'package:work_nexus/features/translation/domain/entities/translation_api_config.dart';

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

Map<String, Object> _reply(String content) => {
  'choices': [
    {
      'message': {'content': content},
    },
  ],
};

const _config = TranslationApiConfig(
  presetId: 'groq',
  baseUrl: 'https://api.example.test/v1/',
  model: 'm-1',
  apiKey: 'sk-test',
);

class _Marker implements TranslationService {
  _Marker(this.name);

  final String name;

  @override
  String contentHash(TicketSource source) => name;

  @override
  Future<void> cancel(String ticketId) async {}

  @override
  Future<Result<TranslationRecord>> translate({
    required String ticketId,
    required TicketSource source,
    required String sourceHash,
    required String targetLang,
    String? model,
  }) async => Err(AgentFailure(name));

  @override
  Future<Result<String>> translateText({
    required String key,
    required String text,
    required String targetLang,
    String? model,
  }) async => Ok(name);
}

void main() {
  ApiTranslationService service(_Adapter adapter, [TranslationApiConfig? c]) =>
      ApiTranslationService(
        Dio()..httpClientAdapter = adapter,
        () async => c ?? _config,
      );

  test(
    'translateText posts to the endpoint with the key and returns text',
    () async {
      final adapter = _Adapter(200, _reply('  Xin chào  '));
      final result = await service(
        adapter,
      ).translateText(key: 'k', text: 'Hello', targetLang: 'vi');

      expect(result.valueOrNull, 'Xin chào');
      expect(
        adapter.last!.uri.toString(),
        'https://api.example.test/v1/chat/completions',
      );
      expect(adapter.last!.headers['Authorization'], 'Bearer sk-test');
      expect((adapter.last!.data as Map)['model'], 'm-1');
    },
  );

  test('a ticket reply wrapped in a code fence is parsed', () async {
    final adapter = _Adapter(
      200,
      _reply('```json\n{"title":"Tiêu đề","body":"Nội dung"}\n```'),
    );
    final result = await service(adapter).translate(
      ticketId: 't',
      source: const TicketSource(title: 'Title', body: 'Body'),
      sourceHash: 'h',
      targetLang: 'vi',
    );

    final record = result.valueOrNull!;
    expect(record.translatedTitle, 'Tiêu đề');
    expect(record.model, 'm-1');
  });

  test('401 is reported as a rejected key and 429 as a rate limit', () async {
    final bad = await service(
      _Adapter(401, {
        'error': {'message': 'bad key'},
      }),
    ).translateText(key: 'k', text: 'x', targetLang: 'vi');
    final busy = await service(
      _Adapter(429, {
        'error': {'message': 'slow down'},
      }),
    ).translateText(key: 'k', text: 'x', targetLang: 'vi');

    expect(bad.failureOrNull, isA<AuthFailure>());
    expect(bad.failureOrNull!.message, contains('bad key'));
    expect(busy.failureOrNull!.message, contains('rate limit'));
  });

  test('no usable configuration is an auth failure, not a request', () async {
    final adapter = _Adapter(200, _reply('x'));
    final result = await service(
      adapter,
      _config.copyWith(enabled: false),
    ).translateText(key: 'k', text: 'x', targetLang: 'vi');

    expect(result.failureOrNull, isA<AuthFailure>());
    expect(adapter.last, isNull);
  });

  group('RoutingTranslationService', () {
    Future<String?> run(TranslationApiConfig? config) async {
      final routing = RoutingTranslationService(
        api: _Marker('api'),
        openCode: _Marker('opencode'),
        config: () async => config,
      );
      return (await routing.translateText(
        key: 'k',
        text: 'x',
        targetLang: 'vi',
      )).valueOrNull;
    }

    test('uses the API when a key is enabled', () async {
      expect(await run(_config), 'api');
    });

    test('falls back to OpenCode when unset or disabled', () async {
      expect(await run(null), 'opencode');
      expect(await run(_config.copyWith(enabled: false)), 'opencode');
    });
  });
}
