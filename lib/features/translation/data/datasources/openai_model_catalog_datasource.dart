import 'package:dio/dio.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/repositories/translation_api_model_catalog.dart';

/// Reads `GET {baseUrl}/models`, the listing every OpenAI-compatible endpoint
/// (Gemini, Groq, OpenRouter, Ollama) serves.
class OpenAiModelCatalogDatasource implements TranslationApiModelCatalog {
  OpenAiModelCatalogDatasource(this._dio);

  final Dio _dio;

  /// Models that cannot answer a chat prompt; Gemini lists them alongside the
  /// chat ones.
  static final _nonChat = RegExp(
    'embed|tts|whisper|imagen|veo|aqa|moderation',
    caseSensitive: false,
  );

  @override
  Future<Result<List<String>>> listModels({
    required String baseUrl,
    required String apiKey,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/models',
        options: Options(
          headers: {if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey'},
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      final ids = idsOf(response.data);
      return ids == null
          ? const Err(ParseFailure('The model list could not be read'))
          : Ok(ids);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      return Err(
        status == 401 || status == 403
            ? AuthFailure('The API rejected the key', cause: e)
            : NetworkFailure('Could not load the model list', cause: e),
      );
    } catch (e) {
      return Err(UnexpectedFailure('Could not load the model list', cause: e));
    }
  }

  /// `data[].id` from the reply. Gemini prefixes ids with `models/`, which its
  /// chat endpoint does not take back.
  static List<String>? idsOf(Object? body) {
    final data = body is Map<String, dynamic> ? body['data'] : null;
    if (data is! List) return null;
    final ids = <String>{
      for (final entry in data)
        if (entry is Map<String, dynamic> && entry['id'] is String)
          (entry['id'] as String).replaceFirst('models/', ''),
    }..removeWhere(_nonChat.hasMatch);
    return ids.toList()..sort();
  }
}
