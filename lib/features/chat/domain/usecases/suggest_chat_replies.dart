import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/chat_message.dart';
import '../repositories/chat_ai_text_generator.dart';
import 'build_chat_transcript.dart';
import 'extract_ai_json.dart';

/// Proposes a few short replies the user could send next, in the language and
/// tone the chat uses, from its latest messages. They are only suggestions:
/// the user picks one into the composer and edits it before sending.
class SuggestChatReplies {
  const SuggestChatReplies(
    this._generator, {
    this.transcript = const BuildChatTranscript(maxChars: 6000),
    this.count = 3,
  });

  final ChatAiTextGenerator _generator;
  final BuildChatTranscript transcript;

  /// How many replies are asked for (and kept at most).
  final int count;

  Future<Result<List<String>>> call(
    List<ChatMessage> messages, {
    required String key,
    required String selfName,
    required String Function(int userId) nameOf,
    String? model,
  }) async {
    final quoted = transcript(messages, nameOf: nameOf, selfName: selfName);
    if (quoted.count == 0) {
      return const Err(UnexpectedFailure('There is nothing to reply to yet'));
    }
    final reply = await _generator.generate(
      key: key,
      prompt: repliesPrompt(quoted.text, selfName, count),
      model: model,
    );
    return reply.fold((answer) {
      final replies = parseReplies(answer.text, count: count);
      return replies.isEmpty
          ? const Err<List<String>>(
              ParseFailure('The model suggested no replies'),
            )
          : Ok(replies);
    }, Err<List<String>>.new);
  }

  /// The replies in the model's answer: the JSON list asked for, else one a
  /// line with any numbering or bullet taken off.
  static List<String> parseReplies(String answer, {required int count}) {
    final json = extractAiJson(answer, array: true);
    final replies = json is List
        ? jsonStrings(json)
        : [
            for (final line in answer.split('\n'))
              if (line.trim().isNotEmpty)
                line.trim().replaceFirst(RegExp(r'^(\d+[.)]|[-*•])\s*'), ''),
          ];
    return [
      for (final r in replies.take(count)) _unquote(r),
    ].where((r) => r.isNotEmpty).toList();
  }

  static String _unquote(String text) =>
      text.replaceAll(RegExp(r'''^["'“”]+|["'“”]+$'''), '').trim();
}

String repliesPrompt(String transcript, String selfName, int count) =>
    'You help $selfName answer in a team chat. Read the latest messages and '
    'write $count different short replies $selfName could send next.\n'
    'Use the language the conversation is written in, and match its tone. '
    'Be natural, specific and brief (under 25 words each). Make them differ '
    '(for example: agree, ask a follow-up question, give a status).\n'
    'Plain text only: no Markdown, no quotes, no sender names.\n'
    'Return ONLY a JSON array of $count strings.\n'
    'Conversation (oldest first):\n'
    '<<<\n$transcript\n>>>';
