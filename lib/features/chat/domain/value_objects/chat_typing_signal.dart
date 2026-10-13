import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_typing_signal.freezed.dart';

/// A chat peer started ([typing]) or stopped typing in [chatGid]. Live only —
/// never stored.
@freezed
abstract class ChatTypingSignal with _$ChatTypingSignal {
  const factory ChatTypingSignal({
    required String chatGid,
    required int userId,
    required bool typing,
  }) = _ChatTypingSignal;
}
