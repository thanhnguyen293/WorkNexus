import '../../../../core/domain/entities/translation_record.dart';
import '../../../../core/error/result.dart';

/// The translatable content of a ticket.
class TicketSource {
  const TicketSource({required this.title, required this.body});

  final String title;
  final String body;
}

/// Produces a Vietnamese translation of a ticket (OpenCode-backed). Caching and
/// state (none/loading/done/outdated/error) are orchestrated by the translation
/// use case + [TranslationRepository]; this only performs the translation.
abstract class TranslationService {
  /// Stable content hash used both to key the cache and to detect outdatedness.
  String contentHash(TicketSource source);

  /// Translate [source]; the returned record echoes [sourceHash] and targetLang.
  Future<Result<TranslationRecord>> translate({
    required String ticketId,
    required TicketSource source,
    required String sourceHash,
  });
}
