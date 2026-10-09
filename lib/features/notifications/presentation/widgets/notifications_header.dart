import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
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
      padding: EdgeInsets.fromLTRB(s.xl, s.md, s.sm, 0),
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
                  style: context.typography.title.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: l.notificationsMarkAllRead,
                color: c.textSecondary,
                icon: const Icon(PhosphorIconsLight.checks),
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
              IconButton(
                tooltip: l.notificationsDeleteRead,
                color: c.textSecondary,
                icon: const Icon(PhosphorIconsLight.trash),
                onPressed: () async {
                  if (!await _confirmDeleteRead(context) || !context.mounted) {
                    return;
                  }
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
              IconButton(
                tooltip: l.refresh,
                color: c.textSecondary,
                onPressed: refreshing
                    ? null
                    : () => ref
                          .read(notificationsRefreshProvider.notifier)
                          .refresh(),
                icon: refreshing
                    ? SizedBox.square(
                        dimension: s.xl3,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(PhosphorIconsLight.arrowClockwise),
              ),
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                color: c.textSecondary,
                onPressed: onClose,
                icon: const Icon(PhosphorIconsLight.x),
              ),
            ],
          ),
          Row(
            children: [
              _Tab(
                label: l.notificationsUnread(unread),
                selected: unreadOnly,
                onTap: () => setTab(true),
              ),
              SizedBox(width: s.lg),
              _Tab(
                label: l.notificationsAll,
                selected: !unreadOnly,
                onTap: () => setTab(false),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<bool> _confirmDeleteRead(BuildContext context) async {
  final l = AppL10n.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(l.notificationsDeleteReadConfirm),
      actions: [
        AppButton.textNeutral(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.cancel),
        ),
        AppButton.error(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.notificationsDelete),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// A text tab with an accent underline when [selected].
class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final t = context.typography;
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: s.xs, vertical: s.sm),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? c.accent : Colors.transparent,
              width: context.borders.thick,
            ),
          ),
        ),
        child: Text(
          label,
          style: (selected ? t.bodyStrong : t.body).copyWith(
            color: selected ? c.accent : c.textSecondary,
          ),
        ),
      ),
    );
  }
}
