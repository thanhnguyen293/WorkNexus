import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/entities/account.dart';
import '../../core/navigation/navigation_providers.dart';
import '../../features/chat/presentation/providers/chat_providers.dart';

/// Opens the chat when the app starts, once a chat account is known (a
/// ZenTao account logs into its chat) — unless the user already went
/// somewhere of their own: only the place the app picked by itself (the
/// dashboard, or the first account the default selection opened) gives way.
/// Runs once per launch.
final launchChatProvider = Provider<void>((ref) {
  var done = false;
  ref.listen<String?>(selectedChatAccountIdProvider, (_, chatAccount) {
    if (done || chatAccount == null) return;
    done = true;
    // On the next turn: the chat account can turn up while the shell is
    // building, and the navigation may not change in the middle of a frame.
    Future.microtask(() {
      final nav = ref.read(appNavProvider);
      final firstAccount = Account.sort(
        ref.read(sortedActiveAccountsProvider),
      ).firstOrNull;
      final pickedByApp = switch (nav.rail) {
        WorkspaceTarget() => !nav.userSelectedWorkspace,
        AccountTarget(:final accountId) => accountId == firstAccount?.id,
        _ => false,
      };
      if (pickedByApp) ref.read(appNavProvider.notifier).selectChat();
    });
  }, fireImmediately: true);
});

/// Keeps [launchChatProvider] alive from a part of the shell that is always
/// mounted.
class ChatAtLaunch extends ConsumerStatefulWidget {
  const ChatAtLaunch({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ChatAtLaunch> createState() => _ChatAtLaunchState();
}

class _ChatAtLaunchState extends ConsumerState<ChatAtLaunch> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(launchChatProvider, (_, _) {});
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
