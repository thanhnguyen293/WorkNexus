import '../entities/translation_record.dart';

/// Persistent cache of successful translations (drift-backed). Translation
/// *state* is derived by comparing the ticket's current source hash to the
/// stored record's hash — see the translation use case.
abstract class TranslationRepository {
  Stream<TranslationRecord?> watchTranslation(String ticketId);
  Future<TranslationRecord?> getTranslation(String ticketId);
  Future<void> saveTranslation(TranslationRecord record);
}
