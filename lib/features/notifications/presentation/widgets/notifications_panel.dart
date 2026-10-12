import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/notification_providers.dart';
import 'notification_day_list.dart';
import 'notifications_header.dart';

/// ZenTao's web notifications (the bell menu) in a panel sliding out beside
/// the rail, over the current view, while [notificationsPanelOpenProvider] is
/// set. It sits under the detail slide-over, so a ticket opened from it shows
/// on the right with the list still in place. Escape, the bell or a click
/// outside closes it.
class NotificationsPanel extends ConsumerWidget {
  const NotificationsPanel({super.key, required this.leftInset});

  /// Where the panel starts: right of the rail, which stays usable.
  final double leftInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(notificationsPanelOpenProvider)) {
      return const SizedBox.shrink();
    }
    final c = context.colors;
    void close() => ref.read(appNavProvider.notifier).closeNotifications();
    return Padding(
      padding: EdgeInsets.only(left: leftInset),
      child: Stack(
        children: [
          Positioned.fill(
            child: ModalBarrier(
              color: c.scrim.withValues(alpha: _kScrimAlpha),
              onDismiss: close,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: _SlideIn(child: _Panel(onClose: close)),
          ),
        ],
      ),
    );
  }
}

/// Dims what the panel covers; a tap on it closes the panel.
const double _kScrimAlpha = 0.12;

class _SlideIn extends StatelessWidget {
  const _SlideIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: -1, end: 0),
    duration: AppMotion.slow,
    curve: AppMotion.enter,
    builder: (context, dx, child) => FractionalTranslation(
      translation: Offset(dx * 0.15, 0),
      child: Opacity(opacity: 1 + dx, child: child),
    ),
    child: child,
  );
}

class _Panel extends ConsumerWidget {
  const _Panel({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final refresh = ref.watch(notificationsRefreshProvider);
    final stored = ref.watch(notificationsProvider);
    final days = ref.watch(notificationDaysProvider);
    final unreadOnly = ref.watch(notificationsUnreadOnlyProvider);
    final failed = (refresh.hasError && !refresh.isLoading) || stored.hasError;
    final Widget body;
    if (days.isNotEmpty) {
      body = NotificationDayList(days: days);
    } else if (refresh.isLoading || (!stored.hasValue && !failed)) {
      body = const AppStateView.loading(compact: true);
    } else if (failed) {
      body = AppStateView.error(
        compact: true,
        title: l.notificationsLoadFailed,
        onRetry: () =>
            ref.read(notificationsRefreshProvider.notifier).refresh(),
      );
    } else {
      body = AppStateView.empty(
        compact: true,
        icon: unreadOnly ? LucideIcons.checkCheck300 : LucideIcons.bellOff300,
        title: unreadOnly ? l.notificationsEmptyUnread : l.notificationsEmpty,
      );
    }
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent ||
            event.logicalKey != LogicalKeyboardKey.escape) {
          return KeyEventResult.ignored;
        }
        onClose();
        return KeyEventResult.handled;
      },
      child: Container(
        width: context.sizes.sidePanel,
        decoration: BoxDecoration(
          color: c.background,
          border: Border(right: context.hairlineSide),
          boxShadow: [
            BoxShadow(
              color: c.scrim.withValues(alpha: _kScrimAlpha),
              blurRadius: s.xl6,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NotificationsHeader(onClose: onClose),
            if (failed && days.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(s.xl, s.md, s.xl, 0),
                child: AppInlineNote(
                  text: l.notificationsRefreshFailed,
                  isError: true,
                ),
              ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
