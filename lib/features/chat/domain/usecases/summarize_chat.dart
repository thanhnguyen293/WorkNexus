import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/chat_message.dart';
import '../entities/chat_summary.dart';
import '../repositories/chat_ai_text_generator.dart';
import 'build_chat_transcript.dart';
import 'extract_ai_json.dart';

/// Summarizes chat messages for someone catching up: an overview, the key
/// points, decisions, action items and open questions, written in
/// [languageName] (the app's language) whatever language the chat is in.
class SummarizeChat {
  const SummarizeChat(
    this._generator, {
    this.transcript = const BuildChatTranscript(),
  });

  final ChatAiTextGenerator _generator;
  final BuildChatTranscript transcript;

  Future<Result<ChatSummary>> call(
    List<ChatMessage> messages, {
    required String key,
    required String languageName,
    required String selfName,
    required String Function(int userId) nameOf,
    String? model,
  }) async {
    final quoted = transcript(messages, nameOf: nameOf, selfName: selfName);
    if (quoted.count == 0) {
      return const Err(UnexpectedFailure('There are no messages to summarize'));
    }
    final reply = await _generator.generate(
      key: key,
      prompt: summaryPrompt(quoted.text, quoted.count, languageName),
      model: model,
    );
    return reply.fold(
      (answer) => Ok(parseSummary(answer, count: quoted.count)),
      Err<ChatSummary>.new,
    );
  }

  /// The model's answer as a summary. One that is not the JSON asked for is
  /// still worth reading, so it becomes the overview as written.
  static ChatSummary parseSummary(ChatAiReply answer, {required int count}) {
    final json = extractAiJson(answer.text);
    if (json is! Map<String, dynamic>) {
      return ChatSummary(
        overview: answer.text.trim(),
        messageCount: count,
        model: answer.model,
      );
    }
    return ChatSummary(
      overview: (json['overview'] as Object?)?.toString().trim() ?? '',
      keyPoints: jsonStrings(json['keyPoints']),
      decisions: jsonStrings(json['decisions']),
      actionItems: [
        if (json['actionItems'] case final List<Object?> items)
          for (final item in items)
            if (item
                case {'task': final String task} &&
                    final Map<String, Object?> fields
                when task.trim().isNotEmpty)
              ChatActionItem(
                task: task.trim(),
                owner: fields['owner']?.toString().trim() ?? '',
                due: fields['due']?.toString().trim() ?? '',
              ),
      ],
      openQuestions: jsonStrings(json['openQuestions']),
      messageCount: count,
      model: answer.model,
    );
  }
}

String summaryPrompt(String transcript, int count, String languageName) =>
    'You are an assistant in a team chat app. Summarize the conversation '
    'below for a teammate who is catching up on it.\n'
    'Write in $languageName. Be concise and factual: use only what the '
    'messages say. Keep names, ticket ids, numbers, links and code as '
    'written.\n'
    'Return ONLY a JSON object with these keys:\n'
    '"overview": 1-3 sentences on what the conversation is about and where '
    'it stands;\n'
    '"keyPoints": the most important points, at most 6 short strings;\n'
    '"decisions": decisions that were made (an empty list when none);\n'
    '"actionItems": things someone is to do, as objects '
    '{"owner": who, or "", "task": what, "due": when, or ""} '
    '(an empty list when none);\n'
    '"openQuestions": questions still unanswered (an empty list when none).\n'
    'Conversation ($count messages, oldest first):\n'
    '<<<\n$transcript\n>>>';
