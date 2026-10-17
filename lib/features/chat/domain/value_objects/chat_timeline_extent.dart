import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_timeline_extent.freezed.dart';

/// How far back a chat's stored timeline — the run of history that reaches
/// the newest message — goes.
@freezed
abstract class ChatTimelineExtent with _$ChatTimelineExtent {
  const ChatTimelineExtent._();

  const factory ChatTimelineExtent({
    /// Server messages in it.
    required int count,

    /// Its oldest server message; null while nothing is stored.
    int? oldestServerId,

    /// When its oldest server message was sent; null while nothing is stored.
    DateTime? oldestSentAt,

    /// Whether it holds the chat's very first message.
    @Default(false) bool reachesStart,
  }) = _ChatTimelineExtent;

  /// Whether it goes back as far as [since] — or, with no [since], to the
  /// chat's first message — so that nothing older is needed.
  bool reaches(DateTime? since) {
    if (reachesStart) return true;
    final oldest = oldestSentAt;
    return since != null && oldest != null && !oldest.isAfter(since);
  }
}
