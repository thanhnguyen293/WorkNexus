import '../../../../core/error/result.dart';
import '../entities/chat_message_translation.dart';

/// Translations of chat messages, kept so each is made once.
abstract class MessageTranslationRepository {
  /// The stored translation of the message into [targetLang]; null if none.
  Future<Result<ChatMessageTranslation?>> find(
    String accountId,
    String gid,
    String targetLang,
  );

  /// The translation as it changes (saved, shown, hidden); null if none.
  Stream<ChatMessageTranslation?> watch(
    String accountId,
    String gid,
    String targetLang,
  );

  Future<Result<void>> setVisible(
    String accountId,
    String gid,
    String targetLang, {
    required bool visible,
  });

  Future<Result<void>> save(ChatMessageTranslation translation);
}
