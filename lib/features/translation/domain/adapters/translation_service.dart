import '../../../../core/domain/entities/translation_record.dart';
import '../../../../core/error/result.dart';

/// The translatable content of a ticket.
class TicketSource {
  const TicketSource({required this.title, required this.body});

  final String title;
  final String body;
}

/// Produces a translation of a ticket (OpenCode-backed) into a chosen language.
/// Caching and state (none/loading/done/outdated/error) are orchestrated by the
/// translation use case + [TranslationRepository]; this only performs the
/// translation.
abstract class TranslationService {
  /// Stable content hash used both to key the cache and to detect outdatedness.
  String contentHash(TicketSource source);

  /// Translate [source] into [targetLang] (a code from `kTranslationLanguages`);
  /// the returned record echoes [sourceHash] and [targetLang]. [model] pins the
  /// `provider/model` to translate with; null leaves the choice to the backend's
  /// own default.
  ///
  /// Implementations must not run forever — a stalled backend has to come back
  /// as a [Failure] so the UI can leave its loading state.
  Future<Result<TranslationRecord>> translate({
    required String ticketId,
    required TicketSource source,
    required String sourceHash,
    required String targetLang,
    String? model,
  });

  /// Translate a free-form [text] (e.g. a chat message) into [targetLang].
  /// [key] identifies the run so [cancel] can stop it. Nothing is cached — the
  /// caller owns the result.
  Future<Result<String>> translateText({
    required String key,
    required String text,
    required String targetLang,
    String? model,
  });

  /// Aborts the in-flight translation for [ticketId]; a no-op when there is
  /// none. The pending [translate] future still completes (with a failure).
  Future<void> cancel(String ticketId);
}
