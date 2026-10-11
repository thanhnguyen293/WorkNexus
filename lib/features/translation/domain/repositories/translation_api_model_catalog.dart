import '../../../../core/error/result.dart';

/// The models an OpenAI-compatible endpoint offers, so the user picks one
/// instead of typing a name the provider may have renamed or retired.
abstract class TranslationApiModelCatalog {
  /// Model ids served at [baseUrl], sorted; [apiKey] is empty for endpoints
  /// that need none (Ollama).
  Future<Result<List<String>>> listModels({
    required String baseUrl,
    required String apiKey,
  });
}
