import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/error/result.dart';
import '../../domain/entities/chat_message.dart';
import 'chat_providers.dart';

/// How many search results one page brings; scrolling or stepping past the
/// last one asks for another page.
const chatSearchPageSize = 100;

/// The results loaded so far, newest first, and whether more are stored.
typedef ChatSearchResults = ({List<ChatMessage> messages, bool hasMore});

const _noResults = (messages: <ChatMessage>[], hasMore: false);

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
  return chatSearchPageSize;
});

/// Matching messages for the current thread.
final chatThreadSearchMatchesProvider = FutureProvider.autoDispose
    .family<ChatSearchResults, ChatThreadKey>((ref, key) {
      final query = ref.watch(chatThreadSearchQueryProvider(key));
      final limit = ref.watch(chatThreadSearchLimitProvider(key));
      return _search(ref, key.accountId, key.chatGid, query, limit);
    });

/// Query for searching across all chats of an account.
final chatGlobalSearchQueryProvider = StateProvider.family<String, String>(
  (ref, accountId) => '',
);

/// How many matches across all chats to load; back to one page for a new
/// query.
final chatGlobalSearchLimitProvider = StateProvider.family<int, String>((
  ref,
  accountId,
) {
  ref.watch(chatGlobalSearchQueryProvider(accountId));
  return chatSearchPageSize;
});

/// Matching messages across all chats of an account.
final chatGlobalSearchResultsProvider = FutureProvider.autoDispose
    .family<ChatSearchResults, String>((ref, accountId) {
      final query = ref.watch(chatGlobalSearchQueryProvider(accountId));
      final limit = ref.watch(chatGlobalSearchLimitProvider(accountId));
      return _search(ref, accountId, null, query, limit);
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
  final result = await ref
      .watch(chatRepositoryProvider)
      .searchMessages(
        accountId,
        chatGid: chatGid,
        query: query,
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
