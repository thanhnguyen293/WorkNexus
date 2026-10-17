import '../../../../core/error/result.dart';
import '../entities/chat_message.dart';
import '../repositories/chat_repository.dart';

/// What loading after a jump window brought: [added] newer messages, or —
/// none being left — the window joined to the timeline, which then holds
/// [joined] messages from the window's start on (null: it could not be
/// joined, the window stays as it is).
typedef NewerMessages = ({int added, int? joined});

/// Extends a jump window towards the newest message — with the stored
/// messages right after it when there are, else from the server; once it
/// reaches the timeline, or nothing newer is left, joins it to the timeline
/// so the chat reads on as usual.
class LoadNewerMessages {
  const LoadNewerMessages(this._repository);

  /// How many stored messages the window grows by at most at once.
  static const windowPage = 50;

  final ChatRepository _repository;

  Future<Result<NewerMessages>> call({
    required String accountId,
    required String chatGid,
    required ChatMessage newestShown,
    required int windowFrom,
  }) async {
    final serverId = newestShown.serverId;
    final index = newestShown.index;
    if (serverId == null || index == null) {
      return const Ok((added: 0, joined: null));
    }
    final stored = await _repository.countAdjacentMessages(
      accountId,
      chatGid,
      index: index,
      older: false,
      limit: windowPage,
    );
    switch (stored) {
      case Ok(:final value) when value > 0:
        return Ok((added: value, joined: null));
      case Err(:final failure):
        return Err(failure);
      case Ok():
        break;
    }
    // Reaching the timeline — which runs up to the newest message — joins
    // it without asking the server for anything newer.
    switch (await _join(accountId, chatGid, windowFrom, index)) {
      case Ok(value: (added: _, joined: int())) && final joined:
        return joined;
      case Err(:final failure):
        return Err(failure);
      case Ok():
        break;
    }
    final loaded = await _repository.loadNewerMessages(
      accountId,
      chatGid,
      afterServerId: serverId,
    );
    switch (loaded) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value) when value > 0:
        return Ok((added: value, joined: null));
      case Ok():
        break;
    }
    return _join(accountId, chatGid, windowFrom, index);
  }

  Future<Result<NewerMessages>> _join(
    String accountId,
    String chatGid,
    int windowFrom,
    int index,
  ) async {
    final joined = await _repository.joinWindowToTimeline(
      accountId,
      chatGid,
      fromIndex: windowFrom,
      toIndex: index,
    );
    return switch (joined) {
      Ok(:final value) => Ok((added: 0, joined: value)),
      Err(:final failure) => Err(failure),
    };
  }
}
