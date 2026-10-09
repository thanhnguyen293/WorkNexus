import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/widgets/app_rail_button.dart';
import '../../../../core/widgets/unread_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_providers.dart';

/// The chat destination of the app rail, with the total unread count. Also
/// keeps every ZenTao account logged into chat (and the cache limit
/// applied), so the count is live before the chat view is opened.
class ChatRailButton extends ConsumerWidget {
  const ChatRailButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(chatAutoConnectProvider);
    if (ref.watch(chatAccountsProvider).isEmpty) return const SizedBox.shrink();
    final unread = ref.watch(chatUnreadTotalProvider);
    return AppRailButton(
      icon: PhosphorIconsLight.chatCircle,
      selectedIcon: PhosphorIconsFill.chatCircle,
      label: AppL10n.of(context).chat,
      selected:
          ref.watch(chatOpenProvider) &&
          !ref.watch(integrationsVisibleProvider),
      onTap: () => showChatView(ref),
      badge: unread > 0 ? UnreadBadge(count: unread) : null,
    );
  }
}
