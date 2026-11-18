import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/chat_message.dart';
import '../repositories/chat_ai_text_generator.dart';
import '../value_objects/chat_draft_tone.dart';
import 'build_chat_transcript.dart';

/// Rewrites what the user is typing in a [ChatDraftTone], keeping its meaning
/// and language. The latest messages are given as context only, so the
/// rewrite fits the conversation without answering it.
class RewriteChatDraft {
  const RewriteChatDraft(
    this._generator, {
    this.transcript = const BuildChatTranscript(maxChars: 3000),
  });

  final ChatAiTextGenerator _generator;
  final BuildChatTranscript transcript;

  Future<Result<String>> call(
    String draft, {
    required ChatDraftTone tone,
    required String key,
    List<ChatMessage> context = const [],
    String selfName = '',
    String Function(int userId)? nameOf,
    String? model,
  }) async {
    if (draft.trim().isEmpty) {
      return const Err(UnexpectedFailure('There is nothing to rewrite'));
    }
    final quoted = nameOf == null
        ? null
        : transcript(context, nameOf: nameOf, selfName: selfName);
    final reply = await _generator.generate(
      key: key,
      prompt: rewritePrompt(draft, tone, context: quoted?.text),
      model: model,
    );
    return reply.fold((answer) {
      final text = _unwrap(answer.text);
      return text.isEmpty
          ? const Err<String>(ParseFailure('The model returned no text'))
          : Ok(text);
    }, Err<String>.new);
  }

  /// The rewrite without the quotes or code fence a model may put around it.
  static String _unwrap(String answer) => answer
      .trim()
      .replaceFirst(RegExp(r'^```\w*\s*'), '')
      .replaceFirst(RegExp(r'\s*```$'), '')
      .replaceAll(RegExp(r'''^["“]+|["”]+$'''), '')
      .trim();
}

String rewritePrompt(String draft, ChatDraftTone tone, {String? context}) {
  final how = switch (tone) {
    ChatDraftTone.clearer =>
      'so it is clear and well written, fixing grammar and spelling',
    ChatDraftTone.formal => 'in a polite, professional tone',
    ChatDraftTone.friendly => 'in a warm, friendly tone',
    ChatDraftTone.shorter => 'to be shorter and to the point',
  };
  final background = context == null || context.isEmpty
      ? ''
      : 'The latest messages, for context only (do not answer them):\n'
            '<<<\n$context\n>>>\n';
  return 'Rewrite this chat message draft $how. Keep its meaning and the '
      'language it is written in; keep @mentions, links, code and emoji as '
      'they are.\n'
      'Return ONLY the rewritten message, with no preface or quotes.\n'
      '$background'
      'Draft:\n<<<\n$draft\n>>>';
}
