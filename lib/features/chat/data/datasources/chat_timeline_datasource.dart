import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';

/// Drift access to a chat's timeline — the run of stored history that
/// reaches the newest message — and to jump windows outside it.
class ChatTimelineDatasource {
  ChatTimelineDatasource(this._db);

  final AppDatabase _db;

  /// After a fresh newest page starting at [index]: when the message just
  /// before it is not in the timeline, what the timeline held below is cut
  /// off from the newest messages (the chat moved on while away), so it is
  /// detached until older pages reach it again.
  Future<void> detachIfCutOffBelow(
    String accountId,
    String cgid,
    int index,
  ) async {
    final m = _db.chatMessages;
    final joined =
        await (_db.select(m)..where(
              (t) =>
                  t.accountId.equals(accountId) &
                  t.cgid.equals(cgid) &
                  t.detached.equals(false) &
                  t.messageIndex.equals(index - 1),
            ))
            .getSingleOrNull();
    if (joined != null) return;
    await (_db.update(m)..where(
          (t) =>
              t.accountId.equals(accountId) &
              t.cgid.equals(cgid) &
              t.detached.equals(false) &
              t.messageIndex.isSmallerThanValue(index),
        ))
        .write(const ChatMessagesCompanion(detached: Value(true)));
  }

  /// Joins a jump window [from]–[to] to the timeline when it reaches it:
  /// the message after [to] is in the timeline, or the timeline has nothing
  /// newer than [to]. Returns how many timeline messages there then are
  /// from [from] on, or null when the window does not reach it.
  Future<int?> joinWindow(
    String accountId,
    String cgid, {
    required int from,
    required int to,
  }) async {
    final m = _db.chatMessages;
    final newer =
        await (_db.select(m)..where(
              (t) =>
                  t.accountId.equals(accountId) &
                  t.cgid.equals(cgid) &
                  t.detached.equals(false) &
                  t.messageIndex.isBiggerThanValue(to),
            ))
            .get();
    final reaches = newer.isEmpty || newer.any((r) => r.messageIndex == to + 1);
    if (!reaches) return null;
    await (_db.update(m)..where(
          (t) =>
              t.accountId.equals(accountId) &
              t.cgid.equals(cgid) &
              t.messageIndex.isBiggerOrEqualValue(from),
        ))
        .write(const ChatMessagesCompanion(detached: Value(false)));
    final count = m.gid.count();
    final row =
        await (_db.selectOnly(m)
              ..addColumns([count])
              ..where(
                m.accountId.equals(accountId) &
                    m.cgid.equals(cgid) &
                    m.detached.equals(false) &
                    (m.messageIndex.isBiggerOrEqualValue(from) |
                        m.messageIndex.isNull()),
              ))
            .getSingle();
    final joined = row.read(count);
    return joined ?? 0;
  }

  /// The stored messages with an index in [from]–[to] (a jump window,
  /// timeline or not), oldest first.
  Stream<List<ChatMessageRow>> watchMessagesInRange(
    String accountId,
    String cgid, {
    required int from,
    required int to,
  }) =>
      (_db.select(_db.chatMessages)
            ..where(
              (m) =>
                  m.accountId.equals(accountId) &
                  m.cgid.equals(cgid) &
                  m.messageIndex.isBetweenValues(from, to),
            )
            ..orderBy([
              (m) => OrderingTerm.asc(m.messageIndex),
              (m) => OrderingTerm.asc(m.sentAt),
            ]))
          .watch();
}

/// How stored messages join a chat's timeline — the run of history that
/// reaches the newest message, which the chat view shows.
enum MessageLink {
  /// New rows join it; a row already stored keeps its place (pushes).
  keep,

  /// A page known to continue the timeline: every row joins it.
  linked,

  /// Fetched on its own: new rows stay out of it, stored ones keep theirs.
  detached,
}
