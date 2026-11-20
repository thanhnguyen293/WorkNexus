/// The limits on asking the AI for reply ideas on its own, so the auto mode
/// stays cheap: one run per message worth answering, only once the chat has
/// gone quiet, and never more than a few times an hour.
class AutoReplyPolicy {
  const AutoReplyPolicy({
    this.quiet = const Duration(seconds: 10),
    this.settleAfterOpen = const Duration(milliseconds: 1500),
    this.maxAge = const Duration(hours: 6),
    this.chatCooldown = const Duration(seconds: 90),
    this.hourlyLimit = 20,
    this.contextMessages = 10,
  });

  /// How long a chat must go without a new message: a group still talking
  /// gets no ideas, they would be stale by the next message.
  final Duration quiet;

  /// How long a chat must stay open first, so flicking through chats does
  /// not ask for each one passed.
  final Duration settleAfterOpen;

  /// An older last message (a chat opened to look something up) gets none.
  final Duration maxAge;

  /// The least time between two runs in the same chat.
  final Duration chatCooldown;

  /// The most runs in any hour, across all chats.
  final int hourlyLimit;

  /// How many of the latest messages an automatic run reads — fewer than a
  /// run the user asks for.
  final int contextMessages;
}
