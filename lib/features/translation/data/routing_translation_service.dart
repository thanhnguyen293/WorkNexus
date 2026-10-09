import '../../../core/domain/entities/translation_record.dart';
import '../../../core/error/result.dart';
import '../domain/adapters/translation_service.dart';
import '../domain/entities/translation_api_config.dart';

/// Translates through the user's API key when one is set up and enabled, and
/// through the OpenCode CLI otherwise.
class RoutingTranslationService implements TranslationService {
  RoutingTranslationService({
    required TranslationService api,
    required TranslationService openCode,
    required Future<TranslationApiConfig?> Function() config,
  }) : _api = api,
       _openCode = openCode,
       _config = config;

  final TranslationService _api;
  final TranslationService _openCode;
  final Future<TranslationApiConfig?> Function() _config;

  /// Which backend each in-flight run went to, so [cancel] reaches it even
  /// when the setting changed meanwhile.
  final Map<String, TranslationService> _inFlight = {};

  Future<TranslationService> _pick() async =>
      (await _config())?.isUsable ?? false ? _api : _openCode;

  @override
  String contentHash(TicketSource source) => _openCode.contentHash(source);

  @override
  Future<Result<TranslationRecord>> translate({
    required String ticketId,
    required TicketSource source,
    required String sourceHash,
    required String targetLang,
    String? model,
  }) async {
    final backend = await _pick();
    _inFlight[ticketId] = backend;
    try {
      return await backend.translate(
        ticketId: ticketId,
        source: source,
        sourceHash: sourceHash,
        targetLang: targetLang,
        model: model,
      );
    } finally {
      _inFlight.remove(ticketId);
    }
  }

  @override
  Future<Result<String>> translateText({
    required String key,
    required String text,
    required String targetLang,
    String? model,
  }) async {
    final backend = await _pick();
    _inFlight[key] = backend;
    try {
      return await backend.translateText(
        key: key,
        text: text,
        targetLang: targetLang,
        model: model,
      );
    } finally {
      _inFlight.remove(key);
    }
  }

  @override
  Future<void> cancel(String ticketId) async =>
      _inFlight[ticketId]?.cancel(ticketId);
}
