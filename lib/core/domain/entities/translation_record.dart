import 'package:freezed_annotation/freezed_annotation.dart';

part 'translation_record.freezed.dart';

/// A cached, successful translation of a ticket's title + body.
///
/// The cache is keyed on [sourceHash]; when the ticket's current content hash
/// differs from this, the translation is considered *outdated*.
@freezed
abstract class TranslationRecord with _$TranslationRecord {
  const factory TranslationRecord({
    required String ticketId,
    required String sourceHash,
    required String targetLang,
    required String translatedTitle,
    required String translatedBody,
    required String model,
    required String templateVersion,
    required DateTime createdAt,
  }) = _TranslationRecord;
}
