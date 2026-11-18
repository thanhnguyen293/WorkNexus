import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_summary.freezed.dart';

/// Something a person in the chat is to do, as the AI read it: [owner] is
/// empty when the messages name no one, [due] when they set no deadline.
@freezed
abstract class ChatActionItem with _$ChatActionItem {
  const factory ChatActionItem({
    required String task,
    @Default('') String owner,
    @Default('') String due,
  }) = _ChatActionItem;
}

/// An AI summary of a stretch of a chat, for catching up on it: what it is
/// about ([overview]), the main points, what was decided, who is to do what
/// and what is still unanswered.
@freezed
abstract class ChatSummary with _$ChatSummary {
  const factory ChatSummary({
    required String overview,
    @Default(<String>[]) List<String> keyPoints,
    @Default(<String>[]) List<String> decisions,
    @Default(<ChatActionItem>[]) List<ChatActionItem> actionItems,
    @Default(<String>[]) List<String> openQuestions,

    /// How many messages were summarized.
    required int messageCount,

    /// The model that wrote it; null when the backend did not say.
    String? model,
  }) = _ChatSummary;
}
