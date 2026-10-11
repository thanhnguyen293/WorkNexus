import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/notification_providers.dart';
import '../util/notification_actions.dart';

/// The panel's top: title, the list-wide actions (mark all read, delete
/// read, refresh) and close, over the Unread / All tabs — like ZenTao's bell
/// menu.
class NotificationsHeader extends ConsumerWidget {
  const NotificationsHeader({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final unreadOnly = ref.watch(notificationsUnreadOnlyProvider);
    final unread = ref.watch(unreadNotificationCountProvider);
    final refreshing = ref.watch(notificationsRefreshProvider).isLoading;
    final accounts = ref.watch(notificationAccountsProvider);
    void setTab(bool v) =>
        ref.read(notificationsUnreadOnlyProvider.notifier).state = v;
    return Container(
      padding: EdgeInsets.fromLTRB(s.xl, s.md, s.sm, s.lg),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: context.hairlineSide),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.notifications,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.title.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ),
              AppIconButton(
                icon: LucideIcons.checkCheck300,
                tooltip: l.notificationsMarkAllRead,
                onPressed: unread == 0
                    ? null
                    : () {
                        for (final a in accounts) {
                          runNotificationCommand(
                            context,
                            ref,
                            (r) => r.markRead(a.id),
                          );
                        }
                      },
              ),
              AppIconButton(
                icon: LucideIcons.trash300,
                tooltip: l.notificationsDeleteRead,
                onPressed: () async {
                  final confirmed = await AppConfirmDialog.show(
                    context,
                    title: l.notificationsDeleteRead,
                    message: l.notificationsDeleteReadConfirm,
                    confirmLabel: l.notificationsDelete,
                    destructive: true,
                  );
                  if (!confirmed || !context.mounted) return;
                  for (final a in accounts) {
                    await runNotificationCommand(
                      context,
                      ref,
                      (r) => r.deleteRead(a.id),
                    );
                    if (!context.mounted) return;
                  }
                },
              ),
              AppIconButton(
                icon: LucideIcons.rotateCw300,
                tooltip: l.refresh,
                isLoading: refreshing,
                onPressed: () =>
                    ref.read(notificationsRefreshProvider.notifier).refresh(),
              ),
              AppIconButton(
                icon: LucideIcons.x300,
                tooltip: l.close,
                onPressed: onClose,
              ),
            ],
          ),
          SizedBox(height: s.md),
          AppSegmentedTabs(
            tabs: [
              AppSegmentedTab(
                label: l.notificationsUnreadTab,
                count: unread,
                active: unreadOnly,
                onTap: () => setTab(true),
              ),
              AppSegmentedTab(
                label: l.notificationsAll,
                active: !unreadOnly,
                onTap: () => setTab(false),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
