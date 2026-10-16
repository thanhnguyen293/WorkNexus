import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/domain/adapters/account_sync_service.dart';
import '../../core/domain/entities/account.dart';
import '../di/service_locator.dart';

/// The account sync service, as a provider so tests can stand one in.
final accountSyncServiceProvider = Provider<AccountSyncService>(
  (ref) => getIt<AccountSyncService>(),
);

/// Syncs every connected account's assigned items once, when the accounts
/// first load at launch — ZenTao, GitLab and GitHub alike. Otherwise nothing
/// syncs an account until the user acts (connect, the account row's sync, the
/// Overview), and its header says "not synced yet" all session. The sync
/// reports its status ([AccountSyncService.syncAccount] tracks it); an
/// account connected later is synced by its connect flow.
final launchAccountSyncProvider = Provider<void>((ref) {
  var started = false;
  ref.listen<AsyncValue<List<Account>>>(accountsProvider, (_, next) {
    final accounts = next.asData?.value;
    if (started || accounts == null) return;
    started = true;
    final sync = ref.read(accountSyncServiceProvider);
    for (final account in accounts) {
      if (account.credentialsRef == null) continue;
      unawaited(sync.syncAccount(account));
    }
  }, fireImmediately: true);
});

/// Keeps [launchAccountSyncProvider] alive from a part of the shell that is
/// always mounted (subscribed once, not from a build).
class AccountSyncAtLaunch extends ConsumerStatefulWidget {
  const AccountSyncAtLaunch({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AccountSyncAtLaunch> createState() =>
      _AccountSyncAtLaunchState();
}

class _AccountSyncAtLaunchState extends ConsumerState<AccountSyncAtLaunch> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(launchAccountSyncProvider, (_, _) {});
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
