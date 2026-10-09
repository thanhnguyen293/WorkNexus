import 'package:flutter/foundation.dart';

/// Which of a chat's messages the thread shows.
@immutable
sealed class ChatMessageWindow {
  const ChatMessageWindow();
}

/// The newest [limit] messages of the timeline; [limit] grows as older
/// pages load.
final class LiveWindow extends ChatMessageWindow {
  const LiveWindow(this.limit);

  final int limit;

  @override
  bool operator ==(Object other) => other is LiveWindow && other.limit == limit;

  @override
  int get hashCode => limit.hashCode;
}

/// A stretch far back in the chat, around a message jumped to: the messages
/// with an index in [from]–[to], growing either way as the user scrolls.
final class AroundWindow extends ChatMessageWindow {
  const AroundWindow({required this.from, required this.to});

  final int from;
  final int to;

  AroundWindow copyWith({int? from, int? to}) =>
      AroundWindow(from: from ?? this.from, to: to ?? this.to);

  @override
  bool operator ==(Object other) =>
      other is AroundWindow && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}
