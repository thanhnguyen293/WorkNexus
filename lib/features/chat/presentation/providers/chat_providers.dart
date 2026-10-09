import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/error/result.dart';
import '../../../../core/platform/desktop_notifier.dart';
import '../../../../core/settings/app_settings.dart';
import '../../domain/entities/chat_cache_usage.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_user.dart';
import '../../domain/entities/link_preview.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/repositories/link_preview_repository.dart';
import '../../domain/usecases/build_reply_thread.dart';
import '../../domain/usecases/load_link_preview.dart';
import '../../domain/value_objects/chat_connection_status.dart';
import '../../domain/value_objects/chat_list_tab.dart';
import '../../domain/value_objects/message_content.dart';
import 'chat_controller.dart';

part 'chat_providers_conversations.dart';
part 'chat_providers_thread.dart';
part 'chat_providers_media.dart';
part 'chat_providers_panels.dart';

/// One open thread: which account, which chat.
typedef ChatThreadKey = ({String accountId, String chatGid});

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => getIt<ChatRepository>(),
);

/// OS notifications for new messages.
final desktopNotifierProvider = Provider<DesktopNotifier>(
  (ref) => getIt<DesktopNotifier>(),
);

/// Whether the OS lets the app show notifications; null where unknown.
/// Invalidate to check again (e.g. when the app comes back to the front).
final chatNotificationPermissionProvider = FutureProvider.autoDispose<bool?>(
  (ref) => ref.watch(desktopNotifierProvider).permissionGranted(),
);

/// The user closed the "notifications are blocked" bar (until restart).
final chatNotificationWarningDismissedProvider = StateProvider<bool>(
  (ref) => false,
);

final chatControllerProvider = Provider<ChatController>(
  (ref) => ChatController(ref.watch(chatRepositoryProvider)),
);

/// Chat exists per connected ZenTao account.
final chatAccountsProvider = Provider<List<Account>>((ref) {
  final accounts = ref.watch(accountsProvider).asData?.value ?? const [];
  return [
    for (final a in accounts)
      if (a.providerType == ProviderType.zentao) a,
  ];
});

/// The account the user picked in the chat view (null = not picked yet).
final pickedChatAccountProvider = StateProvider<String?>((ref) => null);

/// The account the chat view shows: the picked one while it still exists,
/// else the first ZenTao account.
final selectedChatAccountIdProvider = Provider<String?>((ref) {
  final accounts = ref.watch(chatAccountsProvider);
  final picked = ref.watch(pickedChatAccountProvider);
  if (accounts.any((a) => a.id == picked)) return picked;
  return accounts.isEmpty ? null : accounts.first.id;
});

/// Logs every ZenTao account into chat. Watched by the always-visible sidebar
/// entry so unread counts are live before the chat view is opened.
final chatAutoConnectProvider = Provider<void>((ref) {
  final controller = ref.watch(chatControllerProvider);
  // Also applies the attachment cache and video auto-download limits from
  // settings (here because this runs at launch, before the chat view is
  // opened).
  controller.setCacheLimit(
    ref.watch(appSettingsProvider.select((s) => s.chatCacheLimitMb)) *
        1024 *
        1024,
  );
  final (autoVideos, autoVideoMb) = ref.watch(
    appSettingsProvider.select(
      (s) => (s.chatAutoDownloadVideos, s.chatAutoDownloadVideoMb),
    ),
  );
  controller.setVideoAutoDownloadLimit(
    autoVideos ? autoVideoMb * 1024 * 1024 : 0,
  );
  for (final account in ref.watch(chatAccountsProvider)) {
    controller.connect(account.id);
  }
});

final chatStatusProvider = StreamProvider.autoDispose
    .family<ChatConnectionStatus, String>(
      (ref, accountId) =>
          ref.watch(chatRepositoryProvider).watchStatus(accountId),
    );
