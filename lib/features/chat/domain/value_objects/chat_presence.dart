/// Whether a chat user is around, from xxd's user `status`.
enum ChatPresence {
  online,
  busy,
  meeting,
  away,
  offline;

  /// `online`/`busy`/`meeting`/`away` as sent by xxd; anything else
  /// (including `offline`, `unverified` or unknown) is offline.
  static ChatPresence fromStatus(String? status) => switch (status) {
    'online' => online,
    'busy' => busy,
    'meeting' => meeting,
    'away' => away,
    _ => offline,
  };

  /// The presences a user can pick for themselves, in menu order.
  static const selectable = [busy, meeting, away, online];

  /// The xxd `status` string.
  String get status => name;

  bool get isAround => this != offline;
}
