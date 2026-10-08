import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/chat_message_translation.dart';
import '../../domain/repositories/message_translation_repository.dart';
import '../datasources/chat_local_datasource.dart';

class LocalMessageTranslationRepository
    implements MessageTranslationRepository {
  LocalMessageTranslationRepository(this._local);

  final ChatLocalDatasource _local;

  @override
  Future<Result<ChatMessageTranslation?>> find(
    String accountId,
    String gid,
    String targetLang,
  ) async {
    try {
      final row = await _local.messageTranslation(accountId, gid, targetLang);
      return Ok(row == null ? null : _toEntity(row));
    } on Exception catch (e) {
      return Err(StorageFailure('Could not read the translation', cause: e));
    }
  }

  @override
  Stream<ChatMessageTranslation?> watch(
    String accountId,
    String gid,
    String targetLang,
  ) => _local
      .watchMessageTranslation(accountId, gid, targetLang)
      .map((row) => row == null ? null : _toEntity(row));

  @override
  Future<Result<void>> setVisible(
    String accountId,
    String gid,
    String targetLang, {
    required bool visible,
  }) async {
    try {
      await _local.setMessageTranslationVisible(
        accountId,
        gid,
        targetLang,
        visible: visible,
      );
      return const Ok(null);
    } on Exception catch (e) {
      return Err(StorageFailure('Could not update the translation', cause: e));
    }
  }

  ChatMessageTranslation _toEntity(ChatMessageTranslationRow row) =>
      ChatMessageTranslation(
        accountId: row.accountId,
        gid: row.gid,
        targetLang: row.targetLang,
        text: row.translatedText,
        model: row.model.isEmpty ? null : row.model,
        createdAt: row.createdAt,
        visible: row.visible,
      );

  @override
  Future<Result<void>> save(ChatMessageTranslation translation) async {
    try {
      await _local.saveMessageTranslation(
        ChatMessageTranslationsCompanion.insert(
          accountId: translation.accountId,
          gid: translation.gid,
          targetLang: translation.targetLang,
          translatedText: translation.text,
          model: translation.model ?? '',
          createdAt: translation.createdAt,
          visible: Value(translation.visible),
        ),
      );
      return const Ok(null);
    } on Exception catch (e) {
      return Err(StorageFailure('Could not save the translation', cause: e));
    }
  }
}
