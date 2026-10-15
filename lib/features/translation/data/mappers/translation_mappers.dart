import '../../../../core/database/database.dart';
import '../../domain/entities/translation_record.dart';

TranslationRecord translationFromRow(TranslationRow r) => TranslationRecord(
  ticketId: r.ticketId,
  sourceHash: r.sourceHash,
  targetLang: r.targetLang,
  translatedTitle: r.translatedTitle,
  translatedBody: r.translatedBody,
  model: r.model,
  templateVersion: r.templateVersion,
  createdAt: r.createdAt,
);

TranslationsCompanion translationToCompanion(TranslationRecord t) =>
    TranslationsCompanion.insert(
      ticketId: t.ticketId,
      sourceHash: t.sourceHash,
      targetLang: t.targetLang,
      translatedTitle: t.translatedTitle,
      translatedBody: t.translatedBody,
      model: t.model,
      templateVersion: t.templateVersion,
      createdAt: t.createdAt,
    );
