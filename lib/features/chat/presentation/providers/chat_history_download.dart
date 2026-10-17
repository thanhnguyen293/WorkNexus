import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/usecases/download_chat_history.dart';
import '../../domain/value_objects/chat_history_progress.dart';
import 'chat_providers.dart';
import 'chat_search_providers.dart';

part 'chat_history_download.freezed.dart';

/// Where downloading a chat's older history for its search stands.
@freezed
sealed class ChatHistoryDownload with _$ChatHistoryDownload {
  const factory ChatHistoryDownload.idle() = ChatHistoryIdle;

  /// [progress] is null until the server has told how many there are.
  const factory ChatHistoryDownload.running({ChatHistoryProgress? progress}) =
      ChatHistoryRunning;

  const factory ChatHistoryDownload.done() = ChatHistoryDone;

  const factory ChatHistoryDownload.failed(Failure failure) = ChatHistoryFailed;
}

/// Whether the stored history of a chat already goes back as far as the
/// search looks (its first message, or the start of the search period), so
/// there is nothing older to download. Unknown counts as not.
final chatHistoryCompleteProvider = FutureProvider.autoDispose
    .family<bool, ChatThreadKey>((ref, key) async {
      final period = ref.watch(chatSearchPeriodProvider(key.accountId));
      final extent = await ref
          .watch(chatRepositoryProvider)
          .timelineExtent(key.accountId, key.chatGid);
      return extent.valueOrNull?.reaches(period.since(DateTime.now())) ?? false;
    });

/// Downloads one chat's older history while the search shows it; leaving
/// the search stops it, as does [ChatHistoryDownloadController.cancel].
final chatHistoryDownloadProvider = NotifierProvider.autoDispose
    .family<ChatHistoryDownloadController, ChatHistoryDownload, ChatThreadKey>(
      ChatHistoryDownloadController.new,
    );

class ChatHistoryDownloadController extends Notifier<ChatHistoryDownload> {
  ChatHistoryDownloadController(this.thread);

  final ChatThreadKey thread;
  StreamSubscription<Result<ChatHistoryProgress>>? _download;

  @override
  ChatHistoryDownload build() {
    // Another period asks for another download: start over.
    ref.watch(chatSearchPeriodProvider(thread.accountId));
    ref.onDispose(() {
      unawaited(_download?.cancel());
      _download = null;
    });
    return const ChatHistoryDownload.idle();
  }

  void start() {
    if (_download != null) return;
    state = const ChatHistoryDownload.running();
    _download =
        DownloadChatHistory(ref.read(chatRepositoryProvider))(
          accountId: thread.accountId,
          chatGid: thread.chatGid,
          since: ref
              .read(chatSearchPeriodProvider(thread.accountId))
              .since(DateTime.now()),
        ).listen(
          _onProgress,
          onError: (Object e) => _finish(
            ChatHistoryDownload.failed(
              UnexpectedFailure('History download failed', cause: e),
            ),
          ),
          onDone: () => _download = null,
        );
  }

  /// Stops after the page in flight; what arrived so far stays stored.
  void cancel() {
    if (_download == null) return;
    _finish(const ChatHistoryDownload.idle());
  }

  void _onProgress(Result<ChatHistoryProgress> result) {
    switch (result) {
      case Ok(value: ChatHistoryProgress(complete: true)):
        _finish(const ChatHistoryDownload.done());
      case Ok(:final value):
        state = ChatHistoryDownload.running(progress: value);
        _searchAgain();
      case Err(:final failure):
        _finish(ChatHistoryDownload.failed(failure));
    }
  }

  void _finish(ChatHistoryDownload outcome) {
    unawaited(_download?.cancel());
    _download = null;
    state = outcome;
    _searchAgain();
    ref.invalidate(chatHistoryCompleteProvider(thread));
  }

  /// Searches read the stored messages once: each page may bring matches.
  void _searchAgain() {
    ref.invalidate(chatThreadSearchMatchesProvider(thread));
    ref.invalidate(chatGlobalSearchResultsProvider(thread.accountId));
  }
}
