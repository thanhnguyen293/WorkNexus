import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/error/result.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/value_objects/chat_search_period.dart';
import 'chat_providers.dart';

/// How many search results one page brings; scrolling or stepping past the
/// last one asks for another page.
const chatSearchPageSize = 100;

/// The results loaded so far, newest first, and whether more are stored.
typedef ChatSearchResults = ({List<ChatMessage> messages, bool hasMore});

const _noResults = (messages: <ChatMessage>[], hasMore: false);

/// How far back searches of an account look, in whichever chat.
final chatSearchPeriodProvider = StateProvider.family<ChatSearchPeriod, String>(
  (ref, accountId) => ChatSearchPeriod.all,
);

/// Search query for the active in-thread search bar.
final chatThreadSearchQueryProvider =
    StateProvider.family<String, ChatThreadKey>((ref, key) => '');

/// Whether the in-thread search bar is open.
final chatThreadSearchIsOpenProvider =
    StateProvider.family<bool, ChatThreadKey>((ref, key) => false);

/// Active match index (0-based) for the in-thread search bar; -1 until the
/// first step, so that step lands on the first match rather than the second.
final chatThreadSearchActiveIndexProvider =
    StateProvider.family<int, ChatThreadKey>((ref, key) => -1);

/// How many in-thread matches to load; back to one page for a new query.
final chatThreadSearchLimitProvider = StateProvider.family<int, ChatThreadKey>((
  ref,
  key,
) {
  ref.watch(chatThreadSearchQueryProvider(key));
  ref.watch(chatSearchPeriodProvider(key.accountId));
  return chatSearchPageSize;
});

/// Matching messages for the current thread.
final chatThreadSearchMatchesProvider = FutureProvider.autoDispose
    .family<ChatSearchResults, ChatThreadKey>((ref, key) {
      final query = ref.watch(chatThreadSearchQueryProvider(key));
      final limit = ref.watch(chatThreadSearchLimitProvider(key));
      return _search(ref, key.accountId, key.chatGid, query, limit);
    });

/// One more than [limit] is asked for, to know whether more are stored.
/// A failed search is thrown, so it surfaces as the provider's error.
Future<ChatSearchResults> _search(
  Ref ref,
  String accountId,
  String? chatGid,
  String query,
  int limit,
) async {
  if (query.trim().isEmpty) return _noResults;
  final period = ref.watch(chatSearchPeriodProvider(accountId));
  final result = await ref
      .watch(chatRepositoryProvider)
      .searchMessages(
        accountId,
        chatGid: chatGid,
        query: query,
        since: period.since(DateTime.now()),
        limit: limit + 1,
      );
  return switch (result) {
    Ok(:final value) => (
      messages: value.take(limit).toList(),
      hasMore: value.length > limit,
    ),
    Err(:final failure) => throw failure,
  };
}
