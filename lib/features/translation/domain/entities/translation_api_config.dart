/// How translations run when the user brings their own API key instead of the
/// OpenCode CLI. [apiKey] is empty for endpoints that need none (Ollama).
class TranslationApiConfig {
  const TranslationApiConfig({
    required this.presetId,
    required this.baseUrl,
    required this.model,
    this.apiKey = '',
    this.enabled = true,
  });

  final String presetId;
  final String baseUrl;
  final String model;
  final String apiKey;

  /// Off keeps the saved settings but translates through OpenCode again.
  final bool enabled;

  bool get isUsable => enabled && baseUrl.isNotEmpty && model.isNotEmpty;

  TranslationApiConfig copyWith({bool? enabled}) => TranslationApiConfig(
    presetId: presetId,
    baseUrl: baseUrl,
    model: model,
    apiKey: apiKey,
    enabled: enabled ?? this.enabled,
  );
}
