import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_privacy.freezed.dart';

/// The chat's privacy mode, for a shared screen or a look over the shoulder:
/// while [enabled], the parts picked below are hidden on screen until the
/// pointer (or keyboard focus) is on them. Only the display changes; nothing
/// stored or sent does.
@freezed
abstract class ChatPrivacy with _$ChatPrivacy {
  const factory ChatPrivacy({
    /// The master switch; also what the keyboard shortcut flips.
    @Default(false) bool enabled,

    /// The last message under each chat in the chat list: shown as dots.
    @Default(true) bool hidePreviews,

    /// Chat names (shown as dots) and avatars (a plain placeholder), in the
    /// list, atop the open chat and in its composer hint.
    @Default(true) bool hideIdentities,

    /// The messages of the open chat, of threads and pins: faded out.
    @Default(true) bool hideMessages,
  }) = _ChatPrivacy;
}
