import 'package:dio/dio.dart';

import '../../../core/domain/entities/translation_record.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/util/content_hash.dart' as hash;
import '../../../core/util/translation_languages.dart';
import '../domain/adapters/translation_service.dart';
import '../domain/entities/translation_api_config.dart';
import 'translation_prompts.dart';

/// Translates through any OpenAI-compatible `/chat/completions` endpoint with
/// the user's own key (Gemini, Groq, OpenRouter, Ollama, …).
class ApiTranslationService implements TranslationService {
  ApiTranslationService(this._dio, this._config);

  final Dio _dio;

  /// The configuration in force right now; read per call so a saved change
  /// applies without restarting.
  final Future<TranslationApiConfig?> Function() _config;

  static const _templateVersion = 'api-v1';
  final Map<String, CancelToken> _running = {};

  @override
  String contentHash(TicketSource source) =>
      hash.contentHash(source.title, source.body);

  @override
  Future<void> cancel(String ticketId) async {
    _running.remove(ticketId)?.cancel('cancelled');
  }

  @override
  Future<Result<TranslationRecord>> translate({
    required String ticketId,
    required TicketSource source,
    required String sourceHash,
    required String targetLang,
    String? model,
  }) async {
    final language = translationLanguageFor(targetLang);
    final config = await _config();
    final reply = await _complete(
      ticketId,
      config,
      ticketPrompt(source, language.englishName),
    );
    return reply.fold((text) {
      final parsed = extractTicketJson(text);
      if (parsed == null) {
        return Err(ParseFailure('Could not parse the translation: $text'));
      }
      return Ok(
        TranslationRecord(
          ticketId: ticketId,
          sourceHash: sourceHash,
          targetLang: language.code,
          translatedTitle: parsed['title']?.toString() ?? source.title,
          translatedBody: parsed['body']?.toString() ?? source.body,
          model: config!.model,
          templateVersion: _templateVersion,
          createdAt: DateTime.now(),
        ),
      );
    }, Err<TranslationRecord>.new);
  }

  @override
  Future<Result<String>> translateText({
    required String key,
    required String text,
    required String targetLang,
    String? model,
  }) async {
    final language = translationLanguageFor(targetLang);
    final reply = await _complete(
      key,
      await _config(),
      textPrompt(text, language.englishName),
    );
    return reply.fold((out) {
      final trimmed = out.trim();
      return trimmed.isEmpty
          ? const Err<String>(ParseFailure('The model returned no text'))
          : Ok(trimmed);
    }, Err<String>.new);
  }

  Future<Result<String>> _complete(
    String key,
    TranslationApiConfig? config,
    String prompt,
  ) async {
    if (config == null || !config.isUsable) {
      return const Err(AuthFailure('No translation API key is set up'));
    }
    final token = CancelToken();
    _running[key] = token;
    try {
      final response = await _dio.post<Object?>(
        '${config.baseUrl.replaceFirst(RegExp(r'/+$'), '')}/chat/completions',
        cancelToken: token,
        options: Options(
          headers: {
            if (config.apiKey.isNotEmpty)
              'Authorization': 'Bearer ${config.apiKey}',
          },
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 120),
        ),
        data: {
          'model': config.model,
          'temperature': 0.2,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        },
      );
      final text = _contentOf(response.data);
      return text == null
          ? const Err(ParseFailure('The API reply held no message'))
          : Ok(text);
    } on DioException catch (e) {
      return Err(_failureFor(e));
    } catch (e) {
      return Err(UnexpectedFailure('Translation failed: $e', cause: e));
    } finally {
      _running.remove(key);
    }
  }

  static String? _contentOf(Object? body) {
    if (body is! Map<String, dynamic>) return null;
    final choices = body['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    final message = first is Map<String, dynamic> ? first['message'] : null;
    final content = message is Map<String, dynamic> ? message['content'] : null;
    return content is String ? content : null;
  }

  static Failure _failureFor(DioException e) {
    if (CancelToken.isCancel(e)) {
      return const NetworkFailure('Translation cancelled');
    }
    final status = e.response?.statusCode;
    final detail = _errorDetail(e.response?.data);
    return switch (status) {
      401 || 403 => AuthFailure(
        'The translation API rejected the key${_suffix(detail)}',
        cause: e,
      ),
      429 => NetworkFailure(
        'Translation rate limit reached — wait a moment or switch model'
        '${_suffix(detail)}',
        cause: e,
      ),
      final code? => NetworkFailure(
        'Translation API error $code${_suffix(detail)}',
        cause: e,
      ),
      null => NetworkFailure('Could not reach the translation API', cause: e),
    };
  }

  static String _suffix(String? detail) => detail == null ? '' : ': $detail';

  /// `error.message` as OpenAI-style APIs send it (some wrap it in a list).
  static String? _errorDetail(Object? data) {
    final body = data is List && data.isNotEmpty ? data.first : data;
    if (body is! Map<String, dynamic>) return null;
    final error = body['error'];
    final message = error is Map<String, dynamic> ? error['message'] : error;
    if (message is! String || message.isEmpty) return null;
    return message.length <= 200 ? message : '${message.substring(0, 200)}…';
  }
}
