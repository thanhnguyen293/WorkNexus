import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_privacy.freezed.dart';

/// The chat's privacy mode, for a shared screen or a look over the shoulder:
/// while [enabled], the parts picked below are blurred on screen until the
/// pointer (or keyboard focus) is on them. Only the display changes; nothing
/// stored or sent does.
@freezed
abstract class ChatPrivacy with _$ChatPrivacy {
  const factory ChatPrivacy({
    /// The master switch; also what the keyboard shortcut flips.
    @Default(false) bool enabled,

    /// The last message under each chat in the chat list.
    @Default(true) bool blurPreviews,

    /// Chat names and avatars, in the list and atop the open chat.
    @Default(true) bool blurIdentities,

    /// The messages of the open chat and of reply threads.
    @Default(true) bool blurMessages,
  }) = _ChatPrivacy;
}
