import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/app_ref.dart';
import '../../domain/entities/panic_conversation.dart';
import '../../domain/entities/panic_member.dart';
import '../../domain/repositories/app_switcher.dart';
import '../../domain/repositories/panic_chat_gateway.dart';
import '../../domain/usecases/find_panic_switch_account.dart';
import '../../domain/usecases/list_panic_chats.dart';
import '../../domain/usecases/load_panic_group_members.dart';

/// Chat, reached through the switch's own port: it only reads groups and
/// members, listens for messages and sends the sticker.
final panicChatGatewayProvider = Provider<PanicChatGateway>(
  (ref) => getIt<PanicChatGateway>(),
);

/// The ZenTao account the switch works through; null keeps the feature off.
final panicSwitchAccountProvider = Provider<Account?>(
  (ref) => const FindPanicSwitchAccount()(
    ref.watch(accountsProvider).asData?.value ?? const [],
  ),
);

final _panicConversationsProvider = StreamProvider.autoDispose
    .family<List<PanicConversation>, String>(
      (ref, accountId) =>
          ref.watch(panicChatGatewayProvider).watchConversations(accountId),
    );

final _panicUsersProvider = StreamProvider.autoDispose
    .family<Map<int, PanicMember>, String>(
      (ref, accountId) => ref
          .watch(panicChatGatewayProvider)
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
    .family<Result<List<PanicMember>>, PanicGroupKey>(
      (ref, key) => LoadPanicGroupMembers(ref.watch(panicChatGatewayProvider))(
        accountId: key.accountId,
        chatGid: key.chatGid,
      ),
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
