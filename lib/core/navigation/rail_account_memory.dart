import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/value_objects/provider_type.dart';
import 'navigation_providers.dart';

/// The account last opened for each tool, so a rail place of a tool whose
/// sections sit on the rail (`ToolModule.sectionsOnRail`) reopens it. Kept
/// for the session; the first account of the tool is the fallback.
class RailAccountMemory extends Notifier<Map<ProviderType, String>> {
  @override
  Map<ProviderType, String> build() {
    ref.listen(appNavProvider.select((s) => s.rail), (_, rail) {
      if (rail case AccountTarget(:final accountId)) {
        final accounts = ref.read(sortedActiveAccountsProvider);
        final account = accounts.where((a) => a.id == accountId).firstOrNull;
        if (account != null && state[account.providerType] != accountId) {
          state = {...state, account.providerType: accountId};
        }
      }
    }, fireImmediately: true);
    return const {};
  }
}

final railAccountMemoryProvider =
    NotifierProvider<RailAccountMemory, Map<ProviderType, String>>(
      RailAccountMemory.new,
    );
