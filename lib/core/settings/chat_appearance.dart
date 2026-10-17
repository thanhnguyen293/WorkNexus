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

  /// ZenTao: modelled on ZenTao's own chat client — everyone's messages on
  /// the left with an avatar at the top of a run, a header with name and time
  /// over it, small-cornered pale blue (own) and grey bubbles.
  zentao,

  /// WeChat: avatar beside every message on both sides, square bubbles,
  /// centered time stamps.
  wechat,

  /// TBChat: deep-green own bubbles over a doodle wallpaper, name and time
  /// inside a tailed bubble, no avatar beside the messages.
  tbchat,
}
