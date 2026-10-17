import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_timeline_extent.freezed.dart';

/// How far back a chat's stored timeline — the run of history that reaches
/// the newest message — goes.
@freezed
abstract class ChatTimelineExtent with _$ChatTimelineExtent {
  const factory ChatTimelineExtent({
    /// Server messages in it.
    required int count,

    /// Its oldest server message; null while nothing is stored.
    int? oldestServerId,

    /// Whether it holds the chat's very first message.
    @Default(false) bool reachesStart,
  }) = _ChatTimelineExtent;
}
