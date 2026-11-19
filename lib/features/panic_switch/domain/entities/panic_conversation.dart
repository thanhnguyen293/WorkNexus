import 'package:freezed_annotation/freezed_annotation.dart';

part 'panic_conversation.freezed.dart';

/// The kinds of chat the sticker can go to; anything else (bots, system
/// chats) is [other].
enum PanicChatKind { group, direct, other }

/// A chat of the account, as much of it as the switch needs to offer it as a
/// place to send the sticker. Direct chats have no [name]: they are titled
/// after [peerUserId].
@freezed
abstract class PanicConversation with _$PanicConversation {
  const factory PanicConversation({
    required String gid,
    required PanicChatKind kind,
    required String name,
    int? peerUserId,

    /// The user's chat with themself ("My Cloud").
    @Default(false) bool isSelf,
    @Default(false) bool hidden,
  }) = _PanicConversation;
}
