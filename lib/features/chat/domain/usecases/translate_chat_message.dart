import '../../../../core/domain/adapters/translation_service.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/chat_message.dart';
import '../entities/chat_message_translation.dart';
import '../repositories/message_translation_repository.dart';
import '../value_objects/message_content.dart';

/// Translates a text message into [targetLang]: the stored translation when
/// there is one (shown again), otherwise a fresh one, which is stored — shown
/// — for next time.
class TranslateChatMessage {
  const TranslateChatMessage(this._repository, this._service);

  final MessageTranslationRepository _repository;
  final TranslationService _service;

  /// Mentions are sent as `[@Name](@#id)`; the model only needs `@Name`.
  static final _mention = RegExp(r'\[@([^\]]+)\]\(@#\d+\)');

  Future<Result<ChatMessageTranslation>> call(
    ChatMessage message, {
    required String targetLang,
    String? model,
  }) async {
    final content = message.content;
    if (content is! TextContent) {
      return const Err(UnexpectedFailure('Only text can be translated'));
    }
    final stored = await _repository.find(
      message.accountId,
      message.gid,
      targetLang,
    );
    if (stored case Ok(:final value?)) {
      if (!value.visible) {
        await _repository.setVisible(
          message.accountId,
          message.gid,
          targetLang,
          visible: true,
        );
      }
      return Ok(value.copyWith(visible: true));
    }

    final result = await _service.translateText(
      key: 'chat:${message.gid}',
      text: content.text.replaceAllMapped(_mention, (m) => '@${m[1]}'),
      targetLang: targetLang,
      model: model,
    );
    switch (result) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final translation = ChatMessageTranslation(
          accountId: message.accountId,
          gid: message.gid,
          targetLang: targetLang,
          text: value,
          model: model,
          createdAt: DateTime.now(),
        );
        // A failed save only costs a re-translation later; show what we have.
        await _repository.save(translation);
        return Ok(translation);
    }
  }
}
