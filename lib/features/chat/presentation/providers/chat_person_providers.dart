import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/person_directory_provider.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/person_profile.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/usecases/find_shared_groups.dart';
import '../../domain/usecases/list_person_tickets.dart';
import '../../domain/value_objects/chat_connection_status.dart';
import 'chat_providers.dart';

/// A chat user of one account (chat user ids are the ZenTao user ids).
typedef ChatPersonKey = ({String accountId, int userId});

final findSharedGroupsProvider = Provider<FindSharedGroups>(
  (ref) => FindSharedGroups(ref.watch(chatRepositoryProvider)),
);

/// What the tracker knows of a chat user (department, contacts, join date).
/// Null when there is no tracker to ask (tests) or the account is gone.
final chatPersonProfileProvider = FutureProvider.autoDispose
    .family<Result<PersonProfile>?, ChatPersonKey>((ref, key) async {
      final directory = ref.watch(personDirectoryProvider);
      final account = ref.watch(
        chatAccountsProvider.select(
          (all) => all.where((a) => a.id == key.accountId).firstOrNull,
        ),
      );
      if (directory == null || account == null) return null;
      return directory.lookup(account, key.userId);
    });

/// The groups the signed-in user shares with a chat user. Asked again once
/// the chat connects: membership comes from the server.
final chatSharedGroupsProvider = FutureProvider.autoDispose
    .family<Result<List<ChatConversation>>, ChatPersonKey>((ref, key) {
      ref.watch(
        chatStatusProvider(key.accountId).select((s) => s.value is ChatOnline),
      );
      return ref.watch(findSharedGroupsProvider)(key.accountId, key.userId);
    });

/// A ZenTao user's open synced tickets on one account.
final chatPersonTicketsProvider = Provider.autoDispose
    .family<PersonTickets, ({String accountId, String handle})>((ref, key) {
      final tickets = ref.watch(ticketsProvider).value ?? const [];
      return const ListPersonTickets()(
        tickets,
        accountId: key.accountId,
        handle: key.handle,
      );
    });
