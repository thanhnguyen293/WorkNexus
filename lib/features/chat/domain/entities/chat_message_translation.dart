import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_message_translation.freezed.dart';

/// A message's text translated into [targetLang].
@freezed
abstract class ChatMessageTranslation with _$ChatMessageTranslation {
  const factory ChatMessageTranslation({
    required String accountId,
    required String gid,
    required String targetLang,
    required String text,

    /// The model that produced [text]; null when OpenCode's own default ran.
    String? model,
    required DateTime createdAt,

    /// Whether it is shown under the message (hiding keeps it stored).
    @Default(true) bool visible,
  }) = _ChatMessageTranslation;
}
