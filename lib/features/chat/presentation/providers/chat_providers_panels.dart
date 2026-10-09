part of 'chat_providers.dart';

/// Panels that can open beside a chat instead of a reply thread.
enum ChatSidePanel { info, pinned, files, members }

final chatSidePanelProvider =
    StateProvider.family<ChatSidePanel?, ChatThreadKey>((ref, key) => null);

/// The server's role names by code for an account (empty while unknown or
/// offline); used for roles an admin added, which have no name of ours.
final chatRoleNamesProvider = FutureProvider.autoDispose
    .family<Map<String, String>, String>((ref, accountId) async {
      // Asked once online: a failed (offline) ask is not kept, it is asked
      // again when the chat connects. The repository keeps a success.
      final online = ref.watch(
        chatStatusProvider(accountId).select((s) => s.value is ChatOnline),
      );
      if (!online) return const {};
      return switch (await ref
          .watch(chatRepositoryProvider)
          .roleNames(accountId)) {
        Ok(:final value) => value,
        Err() => const {},
      };
    });

/// User ids of a group's members.
final chatMembersProvider = FutureProvider.autoDispose
    .family<Result<List<int>>, ChatThreadKey>(
      (ref, key) =>
          ref.watch(chatRepositoryProvider).members(key.accountId, key.chatGid),
    );

/// Member count of a chat (header subtitle); refetched when the chat opens.
///
/// Kept once known: switching chats otherwise refetched it each time and
/// the header's "N members" blinked out while it loaded. Opening a chat
/// refreshes it in place (the old count shows meanwhile).
final chatMemberCountProvider = FutureProvider.autoDispose
    .family<Result<int>, ChatThreadKey>((ref, key) async {
      final result = await ref
          .watch(chatRepositoryProvider)
          .memberCount(key.accountId, key.chatGid);
      if (result is Ok) ref.keepAlive();
      return result;
    });
