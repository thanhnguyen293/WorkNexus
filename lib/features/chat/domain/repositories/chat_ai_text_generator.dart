import '../../../../core/error/result.dart';

/// What the model answered, and which model did (null when the backend used
/// its own default without naming it).
class ChatAiReply {
  const ChatAiReply(this.text, {this.model});

  final String text;
  final String? model;
}

/// Answers a free-form prompt with the AI backend the user set up for
/// translation (OpenCode, or their own API key), so the chat's AI features
/// need no setup of their own. Implemented in the composition root.
abstract class ChatAiTextGenerator {
  /// Answers [prompt]; [key] names the run so [cancel] can stop it. [model]
  /// pins the model, null leaves it to the backend.
  Future<Result<ChatAiReply>> generate({
    required String key,
    required String prompt,
    String? model,
  });

  /// Stops the run named [key]; its [generate] then completes with a failure.
  Future<void> cancel(String key);
}
