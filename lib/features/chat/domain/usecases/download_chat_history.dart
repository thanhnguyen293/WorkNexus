import '../../../../core/error/result.dart';
import '../repositories/chat_repository.dart';
import '../value_objects/chat_history_progress.dart';
import '../value_objects/chat_timeline_extent.dart';

/// Stores a chat's history on this device — all of it, or back to `since` —
/// so that searching it, which only sees stored messages (the server cannot
/// search them), finds old ones too.
///
/// Pages back from the oldest message of the stored timeline, not the oldest
/// stored one: stored history may have gaps (pinned messages and reply
/// parents are fetched by id), and each page continues the timeline. Emits
/// the progress before each page and ends with a `complete` one, or with the
/// failure that stopped it. Cancelling the subscription stops it after the
/// page in flight.
class DownloadChatHistory {
  const DownloadChatHistory(this._repository);

  final ChatRepository _repository;

  Stream<Result<ChatHistoryProgress>> call({
    required String accountId,
    required String chatGid,
    DateTime? since,
  }) async* {
    var extent = await _repository.timelineExtent(accountId, chatGid);
    if (extent case Ok(:final value) when value.reaches(since)) {
      yield Ok(_complete(value.count, value.count));
      return;
    }
    // Back to a date, how many messages that is is unknown: the progress
    // has no total then (the server only counts the whole chat).
    var total = 0;
    if (since == null) {
      switch (await _repository.messageCount(accountId, chatGid)) {
        case Ok(:final value):
          total = value;
        case Err(:final failure):
          yield Err(failure);
          return;
      }
    }
    if (extent case Ok(value: ChatTimelineExtent(oldestServerId: null))) {
      // Nothing stored yet: start from the newest page.
      final refreshed = await _repository.refreshMessages(accountId, chatGid);
      if (refreshed case Err(:final failure)) {
        yield Err(failure);
        return;
      }
      extent = await _repository.timelineExtent(accountId, chatGid);
    }
    while (true) {
      final ChatTimelineExtent current;
      switch (extent) {
        case Ok(:final value):
          current = value;
        case Err(:final failure):
          yield Err(failure);
          return;
      }
      final oldest = current.oldestServerId;
      if (current.reaches(since) || oldest == null) {
        yield Ok(_complete(current.count, total));
        return;
      }
      yield Ok(ChatHistoryProgress(stored: current.count, total: total));
      final page = await _repository.loadOlderMessages(
        accountId,
        chatGid,
        beforeServerId: oldest,
      );
      switch (page) {
        case Err(:final failure):
          yield Err(failure);
          return;
        case Ok(value: 0):
          // The server has nothing older: this is the start.
          yield Ok(_complete(current.count, total));
          return;
        case Ok():
          extent = await _repository.timelineExtent(accountId, chatGid);
      }
      // A page that reached no further back would be asked for forever.
      if (extent case Ok(
        :final value,
      ) when (value.oldestServerId ?? oldest) >= oldest) {
        yield Ok(_complete(value.count, total));
        return;
      }
    }
  }

  /// The server's count may leave out messages it no longer lists.
  static ChatHistoryProgress _complete(int stored, int total) =>
      ChatHistoryProgress(
        stored: stored,
        total: stored > total ? stored : total,
        complete: true,
      );
}
