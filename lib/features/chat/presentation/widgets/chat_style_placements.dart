/// Where [ChatStyle]'s pieces go: avatars, names, times, reply quotes and
/// separators. Kept apart from the style itself, which only refers to them.
library;

/// Where a sender's avatar sits within a run of their messages.
enum ChatAvatarPlacement { firstOfRun, lastOfRun, everyMessage }

/// Where the name of a group-chat sender goes.
enum ChatNamePlacement {
  aboveBubble,
  insideBubble,

  /// A header over the first bubble of every run, for own messages and
  /// one-to-one chats too, with the run's time beside the name (ZenTao).
  header,

  /// Above the avatar and bubble together, so the avatar lines up with the
  /// bubble rather than with the name (TBChat).
  aboveRow,
}

/// Where a message's time goes.
enum ChatTimePlacement {
  /// Under the content, on the last message of a run.
  belowContent,

  /// Bottom-right inside the bubble, on every message (Telegram).
  insideEnd,

  /// Bottom inside the bubble, on every message, on the side the bubble is
  /// aligned to: left for others' messages, right for own (TBChat).
  insideAligned,

  /// Not on messages: centered time separators after pauses instead.
  separators,

  /// In the run's header, beside the name ([ChatNamePlacement.header]).
  header,
}

/// Where a reply's quote of the original goes.
enum ChatQuotePlacement { inside, above, below }

/// How date and time separators look.
enum ChatSeparatorStyle { hairline, pill, plain }
