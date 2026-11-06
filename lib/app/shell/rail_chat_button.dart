import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/navigation/navigation_providers.dart';
import '../../core/widgets/app_rail_labeled_button.dart';
import '../../core/widgets/unread_badge.dart';
import '../../features/chat/presentation/providers/chat_providers.dart';
import '../../l10n/app_localizations.dart';

/// The rail's chat button, with the unread count across chat accounts. Shown
/// once a chat account exists (a ZenTao account logs into its chat).
class RailChatButton extends ConsumerWidget {
  const RailChatButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(selectedChatAccountIdProvider) == null) {
      return const SizedBox.shrink();
    }
    final unread = ref.watch(chatUnreadTotalProvider);
    final selected =
        ref.watch(chatOpenProvider) && !ref.watch(miniAppOnScreenProvider);
    return AppRailLabeledButton(
      key: const ValueKey('rail-chat-button'),
      leading: const Icon(LucideIcons.messageSquare300),
      label: AppL10n.of(context).chat,
      selected: selected,
      badge: unread > 0 ? UnreadBadge(count: unread) : null,
      onTap: () => ref.read(appNavProvider.notifier).selectChat(),
    );
  }
}
