import '../entities/chat_message.dart';

/// A reply thread: the message everything replies to, and its replies.
typedef ReplyThread = ({int rootId, List<ChatMessage> replies});

/// What a thread looks like from its root: how many replies, who replied
/// (most recent first, distinct) and when the latest reply came.
typedef ThreadSummary = ({
  int count,
  List<int> replierIds,
  DateTime lastReplyAt,
});

/// Groups replies into threads.
///
/// xxd stores only "replies to message N", and a reply can itself be replied
/// to, so a thread is everything whose parent chain leads to the same root —
/// the first message in the chain that is not itself a known reply.
class BuildReplyThread {
  const BuildReplyThread();

  /// The root of [messageId]'s thread, given every known reply.
  int rootOf(int messageId, List<ChatMessage> replies) {
    final parentOf = {
      for (final r in replies)
        if (r.serverId != null && r.replyToId != null)
          r.serverId!: r.replyToId!,
    };
    var id = messageId;
    final seen = <int>{id};
    // `seen` guards against a malformed cycle in server data.
    for (
      var parent = parentOf[id];
      parent != null && seen.add(parent);
      parent = parentOf[id]
    ) {
      id = parent;
    }
    return id;
  }

  /// The thread rooted at the root of [messageId], replies oldest first.
  ReplyThread call(int messageId, List<ChatMessage> replies) {
    final root = rootOf(messageId, replies);
    final inThread = [
      for (final r in replies)
        if (r.replyToId != null && rootOf(r.replyToId!, replies) == root) r,
    ]..sort((a, b) => a.sentAt.compareTo(b.sentAt));
    return (rootId: root, replies: inThread);
  }

  /// Reply counts per thread root, for "N replies" labels.
  Map<int, int> countsByRoot(List<ChatMessage> replies) {
    final counts = <int, int>{};
    for (final r in replies) {
      final parent = r.replyToId;
      if (parent == null) continue;
      final root = rootOf(parent, replies);
      counts[root] = (counts[root] ?? 0) + 1;
    }
    return counts;
  }

  /// Summaries per thread root, for the thread chip under a root message.
  Map<int, ThreadSummary> summariesByRoot(List<ChatMessage> replies) {
    final byRoot = <int, List<ChatMessage>>{};
    for (final r in replies) {
      final parent = r.replyToId;
      if (parent == null) continue;
      byRoot.putIfAbsent(rootOf(parent, replies), () => []).add(r);
    }
    return {
      for (final MapEntry(key: root, value: list) in byRoot.entries)
        root: _summarize(list),
    };
  }

  static ThreadSummary _summarize(List<ChatMessage> list) {
    final newestFirst = [...list]..sort((a, b) => b.sentAt.compareTo(a.sentAt));
    final repliers = <int>[];
    for (final m in newestFirst) {
      if (!repliers.contains(m.senderId)) repliers.add(m.senderId);
    }
    return (
      count: list.length,
      replierIds: repliers,
      lastReplyAt: newestFirst.first.sentAt,
    );
  }
}
