/// How chat messages are laid out — modelled on familiar messengers so people
/// can keep the look they are used to. Colours always come from the app theme.
enum ChatAppearance {
  /// WorkNexus default: soft bubbles, runs, thread chips.
  worknexus,

  /// Telegram: tinted own bubbles, time inside the bubble, avatar at the end
  /// of a run, coloured sender names.
  telegram,

  /// Zalo: bordered cards, avatar on the first message, name and time inside.
  zalo,

  /// Messenger: solid accent own bubbles, very round, no per-message time.
  messenger,

  /// WeChat: avatar beside every message on both sides, square bubbles,
  /// centered time stamps.
  wechat,

  /// TBChat: deep-green own bubbles over a doodle wallpaper, name and time
  /// inside a tailed bubble, no avatar beside the messages.
  tbchat,
}
