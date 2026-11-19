import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/error/result.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/repositories/chat_group_repository.dart';
import '../../domain/usecases/list_chat_categories.dart';
import '../../domain/usecases/rename_chat_category.dart';
import '../../domain/usecases/set_chat_category.dart';
import '../../domain/value_objects/chat_list_filter.dart';
import 'chat_group_providers.dart';
import 'chat_providers.dart';

/// Filing chats under the user's own categories. Each command delegates to
/// one use case (CLAUDE.md 2.4).
class ChatCategoryController {
  ChatCategoryController(ChatGroupRepository repository)
    : _set = SetChatCategory(repository),
      _rename = RenameChatCategory(repository);

  final SetChatCategory _set;
  final RenameChatCategory _rename;

  Future<Result<void>> setCategory(ChatConversation chat, String category) =>
      _set(chat, category);

  Future<Result<void>> rename(
    String accountId,
    Iterable<ChatConversation> chats, {
    required String from,
    required String to,
  }) => _rename(accountId, chats, from: from, to: to);

  /// Leaves the category's chats uncategorised, which ends it.
  Future<Result<void>> delete(
    String accountId,
    Iterable<ChatConversation> chats,
    String category,
  ) => _rename(accountId, chats, from: category, to: '');
}

final chatCategoryControllerProvider = Provider<ChatCategoryController>(
  (ref) => ChatCategoryController(ref.watch(chatGroupRepositoryProvider)),
);

/// The categories the chat list is narrowed to (none: any).
final chatListCategoriesProvider = StateProvider<Set<String>>((ref) => {});

/// Whether the chat list shows only chats with unread messages.
final chatListUnreadOnlyProvider = StateProvider<bool>((ref) => false);

/// The chat list's filter: the tab, unread only, and the picked categories
/// that still have chats (one emptied since drops out).
final chatListFilterProvider = Provider.autoDispose<ChatListFilter>((ref) {
  final known = ref.watch(chatCategoriesProvider);
  return ChatListFilter(
    tab: ref.watch(chatListTabProvider),
    unreadOnly: ref.watch(chatListUnreadOnlyProvider),
    categories: ref
        .watch(chatListCategoriesProvider)
        .where(known.containsKey)
        .toSet(),
  );
});

/// The open account's categories, A–Z, each with its unread count.
final chatCategoriesProvider = Provider.autoDispose<Map<String, int>>((ref) {
  final accountId = ref.watch(selectedChatAccountIdProvider);
  if (accountId == null) return const {};
  final chats =
      ref.watch(chatConversationsProvider(accountId)).value ??
      const <ChatConversation>[];
  return const ListChatCategories()(chats);
});
