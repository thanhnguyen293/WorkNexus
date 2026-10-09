import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/di/service_locator.dart';
import '../../core/domain/value_objects/provider_type.dart';
import '../../features/chat/presentation/providers/chat_providers.dart';
import '../../features/connections/domain/entities/cache_section.dart';
import '../../features/connections/domain/usecases/refresh_zentao_profile.dart';
import '../../features/dashboard/presentation/providers/dashboard_providers.dart';
import '../../features/notifications/presentation/providers/notification_providers.dart';
import '../../features/sync/data/sync_service.dart';

/// After [sections] of the local cache were cleared, fetches them again —
/// the app shell is the one place that may reach every feature that owns
/// part of the cache. Translations come back on demand, so need nothing.
void reloadAfterCacheClear(WidgetRef ref, Set<CacheSection> sections) {
  final accounts = ref.read(lookupsProvider).accounts.values.toList();
  if (sections.contains(CacheSection.tickets)) {
    final sync = getIt<SyncService>();
    for (final account in accounts) {
      unawaited(sync.syncAccount(account));
    }
  }
  if (sections.contains(CacheSection.dashboard)) {
    ref
      ..invalidate(dashboardRefreshProvider)
      ..invalidate(myWorkSyncProvider)
      ..invalidate(notificationsRefreshProvider);
    final refreshProfile = getIt<RefreshZenTaoProfile>();
    for (final account in accounts) {
      if (account.providerType == ProviderType.zentao &&
          account.credentialsRef != null) {
        unawaited(refreshProfile(account));
      }
    }
  }
  if (sections.contains(CacheSection.chat)) {
    final chat = ref.read(chatControllerProvider);
    for (final account in ref.read(chatAccountsProvider)) {
      unawaited(chat.reconnect(account.id));
    }
  }
}
