import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/widgets/app_rail_button.dart';
import '../../../../core/widgets/unread_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/notification_providers.dart';

/// The notifications destination of the app rail, with the unread count.
/// Watching the refresh provider keeps the list polled while the app runs, so
/// the count is live before the page is opened.
class NotificationsRailButton extends ConsumerWidget {
  const NotificationsRailButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(notificationAccountsProvider).isEmpty) {
      return const SizedBox.shrink();
    }
    ref.watch(notificationsRefreshProvider);
    final unread = ref.watch(unreadNotificationCountProvider);
    return AppRailButton(
      icon: LucideIcons.bell300,
      label: AppL10n.of(context).notifications,
      selected: ref.watch(notificationsPanelOpenProvider),
      onTap: () => ref
          .read(notificationsPanelOpenProvider.notifier)
          .update((open) => !open),
      badge: unread > 0 ? UnreadBadge(count: unread) : null,
    );
  }
}
