import 'package:freezed_annotation/freezed_annotation.dart';

import 'chat_typing_signal.dart';

part 'typing_roster.freezed.dart';

/// Who is typing in which chat, each entry valid until its expiry.
///
/// A peer's client repeats "typing" every few seconds while keys are pressed
/// but may never say it stopped (the official client does not), so an entry
/// lapses on its own after [ttl] unless refreshed.
@freezed
abstract class TypingRoster with _$TypingRoster {
  const factory TypingRoster({
    /// chat gid → user id → when that user's typing lapses.
    @Default(<String, Map<int, DateTime>>{})
    Map<String, Map<int, DateTime>> expiries,
  }) = _TypingRoster;

  const TypingRoster._();

  /// How long one "typing" signal lasts without a refresh.
  static const ttl = Duration(seconds: 5);

  /// The roster after [signal] arrived at [now]. Signals about [selfUserId]
  /// (the server may echo our own) are ignored.
  TypingRoster apply(ChatTypingSignal signal, DateTime now, {int? selfUserId}) {
    if (signal.userId == selfUserId) return this;
    final chat = {...?expiries[signal.chatGid]};
    if (signal.typing) {
      chat[signal.userId] = now.add(ttl);
    } else if (chat.remove(signal.userId) == null) {
      return this;
    }
    return copyWith(
      expiries: {
        for (final e in expiries.entries)
          if (e.key != signal.chatGid) e.key: e.value,
        if (chat.isNotEmpty) signal.chatGid: chat,
      },
    );
  }

  /// The roster without the entries lapsed by [now].
  TypingRoster prune(DateTime now) {
    final next = <String, Map<int, DateTime>>{};
    var changed = false;
    for (final e in expiries.entries) {
      final live = {
        for (final u in e.value.entries)
          if (u.value.isAfter(now)) u.key: u.value,
      };
      if (live.length != e.value.length) changed = true;
      if (live.isNotEmpty) next[e.key] = live;
    }
    return changed ? copyWith(expiries: next) : this;
  }

  /// Users typing in [chatGid], earliest to start first.
  List<int> typingIn(String chatGid) {
    final chat = expiries[chatGid];
    if (chat == null) return const [];
    return (chat.entries.toList()..sort((a, b) => a.value.compareTo(b.value)))
        .map((e) => e.key)
        .toList();
  }

  /// The soonest moment an entry lapses, or null when nobody is typing.
  DateTime? get nextExpiry {
    DateTime? soonest;
    for (final chat in expiries.values) {
      for (final at in chat.values) {
        if (soonest == null || at.isBefore(soonest)) soonest = at;
      }
    }
    return soonest;
  }
}
