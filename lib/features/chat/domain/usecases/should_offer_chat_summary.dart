/// Whether opening a chat offers to summarize what came in meanwhile: only
/// when there is more than a quick scroll's worth of unread messages.
class ShouldOfferChatSummary {
  const ShouldOfferChatSummary({this.threshold = 20});

  /// The fewest unread messages worth a summary.
  final int threshold;

  bool call({required int unread}) => unread >= threshold;
}
