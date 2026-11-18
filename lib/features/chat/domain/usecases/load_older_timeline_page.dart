import '../../../../core/error/result.dart';
import '../repositories/chat_local_api.dart';
import '../repositories/chat_repository.dart';
import '../value_objects/chat_timeline_extent.dart';

/// Stores one more page of a chat's history, before the oldest message of
/// its stored timeline — for a local AI tool that reads the stored history
/// and found too little of it.
///
/// Pages back from the oldest *timeline* message, not the oldest stored one
/// (see `DownloadChatHistory`): stored history may have gaps. With nothing
/// stored yet it fetches the newest page instead.
class LoadOlderTimelinePage {
  const LoadOlderTimelinePage(this._repository);

  final ChatRepository _repository;

  /// The largest page a caller may ask for.
  static const maxPageSize = 200;

  Future<Result<ChatHistoryStep>> call({
    required String accountId,
    required String chatGid,
    int pageSize = 100,
  }) async {
    final ChatTimelineExtent before;
    switch (await _repository.timelineExtent(accountId, chatGid)) {
      case Ok(:final value):
        before = value;
      case Err(:final failure):
        return Err(failure);
    }
    if (before.reachesStart) return const Ok((loaded: 0, reachesStart: true));
    final oldest = before.oldestServerId;
    if (oldest == null) {
      final refreshed = await _repository.refreshMessages(accountId, chatGid);
      if (refreshed case Err(:final failure)) return Err(failure);
      return switch (await _repository.timelineExtent(accountId, chatGid)) {
        Ok(:final value) => Ok((
          loaded: value.count,
          reachesStart: value.reachesStart || value.count == 0,
        )),
        Err(:final failure) => Err(failure),
      };
    }
    final page = await _repository.loadOlderMessages(
      accountId,
      chatGid,
      beforeServerId: oldest,
      pageSize: pageSize.clamp(1, maxPageSize),
    );
    final int arrived;
    switch (page) {
      case Ok(:final value):
        arrived = value;
      case Err(:final failure):
        return Err(failure);
    }
    return switch (await _repository.timelineExtent(accountId, chatGid)) {
      Ok(:final value) => Ok((
        loaded: arrived,
        // Nothing older, or a page that reached no further back: asking
        // again would get the same, so the caller should stop here.
        reachesStart:
            value.reachesStart ||
            arrived == 0 ||
            (value.oldestServerId ?? oldest) >= oldest,
      )),
      Err(:final failure) => Err(failure),
    };
  }
}
