import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/error/result.dart';
import '../../../chat/domain/entities/chat_conversation.dart';
import '../../../chat/domain/entities/chat_user.dart';
import '../../../chat/domain/repositories/chat_repository.dart';
import '../../domain/entities/app_ref.dart';
import '../../domain/repositories/app_switcher.dart';
import '../../domain/usecases/find_panic_switch_account.dart';
import '../../domain/usecases/list_panic_chats.dart';
import '../../domain/usecases/load_panic_group_members.dart';

/// Chat, reached through its domain interface: the panic switch only reads
/// groups and members and listens for messages.
final panicChatRepositoryProvider = Provider<ChatRepository>(
  (ref) => getIt<ChatRepository>(),
);

/// The ZenTao account the switch works through; null keeps the feature off.
final panicSwitchAccountProvider = Provider<Account?>(
  (ref) => const FindPanicSwitchAccount()(
    ref.watch(accountsProvider).asData?.value ?? const [],
  ),
);

final _panicConversationsProvider = StreamProvider.autoDispose
    .family<List<ChatConversation>, String>(
      (ref, accountId) =>
          ref.watch(panicChatRepositoryProvider).watchConversations(accountId),
    );

final _panicUsersProvider = StreamProvider.autoDispose
    .family<Map<int, ChatUser>, String>(
      (ref, accountId) => ref
          .watch(panicChatRepositoryProvider)
          .watchUsers(accountId)
          .map((users) => {for (final u in users) u.userId: u}),
    );

/// The chats the sticker can go to (groups and one-to-one chats), by title;
/// null until the account's chats are loaded.
typedef PanicChatsKey = ({String accountId, String selfTitle});

final panicChatsProvider = Provider.autoDispose
    .family<List<PanicChat>?, PanicChatsKey>((ref, key) {
      final chats = ref.watch(_panicConversationsProvider(key.accountId));
      final users = ref.watch(_panicUsersProvider(key.accountId));
      final loaded = chats.asData?.value;
      if (loaded == null) return null;
      return const ListPanicChats()(
        loaded,
        users.asData?.value ?? const {},
        selfTitle: key.selfTitle,
      );
    });

typedef PanicGroupKey = ({String accountId, String chatGid});

/// The members of the chosen group who could send the sticker.
final panicGroupMembersProvider = FutureProvider.autoDispose
    .family<Result<List<ChatUser>>, PanicGroupKey>(
      (ref, key) => LoadPanicGroupMembers(
        ref.watch(panicChatRepositoryProvider),
      )(accountId: key.accountId, chatGid: key.chatGid),
    );

final appSwitcherProvider = Provider<AppSwitcher>(
  (ref) => getIt<AppSwitcher>(),
);

/// Apps on this computer to pick from (read again each time Settings opens).
final panicAppsProvider = FutureProvider.autoDispose<Result<List<AppRef>>>(
  (ref) => ref.watch(appSwitcherProvider).listApps(),
);

/// An app's icon (PNG bytes), null when it has none. Not auto-disposed: icons
/// never change while the app runs, and the checklist scrolls rows in and out.
final panicAppIconProvider = FutureProvider.family<Uint8List?, AppRef>(
  (ref, app) async =>
      (await ref.watch(appSwitcherProvider).appIcon(app)).valueOrNull,
);
