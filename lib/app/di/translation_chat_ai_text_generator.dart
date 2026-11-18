import '../../core/error/result.dart';
import '../../features/chat/domain/repositories/chat_ai_text_generator.dart';
import '../../features/translation/domain/adapters/translation_service.dart';

/// Lets the chat's AI features (summaries, reply ideas, rewrites) run on the
/// translation backend the user set up, without chat depending on the
/// translation feature: the composition root is the one place that knows
/// both.
class TranslationChatAiTextGenerator implements ChatAiTextGenerator {
  const TranslationChatAiTextGenerator(this._service);

  final TranslationService _service;

  @override
  Future<Result<ChatAiReply>> generate({
    required String key,
    required String prompt,
    String? model,
  }) async {
    final result = await _service.complete(
      key: key,
      prompt: prompt,
      model: model,
    );
    return result.fold(
      (reply) => Ok(ChatAiReply(reply.text, model: reply.model)),
      Err<ChatAiReply>.new,
    );
  }

  @override
  Future<void> cancel(String key) => _service.cancel(key);
}
