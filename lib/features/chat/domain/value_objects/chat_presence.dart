/// Whether a chat user is around, from xxd's user `status`.
enum ChatPresence {
  online,
  away,
  busy,
  offline;

  /// `online`/`away`/`busy` as sent by xxd; anything else (including
  /// `offline`, `unverified` or unknown) is offline.
  static ChatPresence fromStatus(String? status) => switch (status) {
    'online' => online,
    'away' => away,
    'busy' => busy,
    _ => offline,
  };

  bool get isAround => this != offline;
}
