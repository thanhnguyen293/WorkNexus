import '../../../core/domain/entities/translation_record.dart';
import '../../../core/error/result.dart';
import '../../../core/util/content_hash.dart';
import '../domain/adapters/translation_service.dart';

/// Demo translation service used before the real OpenCode wiring (Phase 6).
/// Simulates latency and returns the seeded Vietnamese text so the Translate
/// button produces a genuine result end-to-end.
class MockTranslationService implements TranslationService {
  MockTranslationService(
    this._viByTicketId, {
    this.delay = const Duration(milliseconds: 1200),
  });

  final Map<String, ({String title, String body})> _viByTicketId;
  final Duration delay;

  @override
  String contentHash(TicketSource source) =>
      contentHashOf(source.title, source.body);

  @override
  Future<Result<TranslationRecord>> translate({
    required String ticketId,
    required TicketSource source,
    required String sourceHash,
  }) async {
    await Future.delayed(delay);
    final vi = _viByTicketId[ticketId];
    return Ok(
      TranslationRecord(
        ticketId: ticketId,
        sourceHash: sourceHash,
        targetLang: 'vi',
        translatedTitle: vi?.title ?? '[VI] ${source.title}',
        translatedBody: vi?.body ?? source.body,
        model: 'mock/opencode',
        templateVersion: 'v1',
        createdAt: DateTime.now(),
      ),
    );
  }
}

/// Exposed so the service and fixtures share one hashing function.
String contentHashOf(String title, String body) => contentHash(title, body);
