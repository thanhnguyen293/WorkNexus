import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_providers.dart';

/// A warning strip above the chat while message notifications are on in the
/// app but blocked by the OS. "Turn on" asks again, or — as macOS asks only
/// once — opens System Settings; coming back to the app checks again.
class ChatNotificationBanner extends ConsumerStatefulWidget {
  const ChatNotificationBanner({super.key});

  @override
  ConsumerState<ChatNotificationBanner> createState() =>
      _ChatNotificationBannerState();
}

class _ChatNotificationBannerState
    extends ConsumerState<ChatNotificationBanner> {
  late final _lifecycle = AppLifecycleListener(
    onResume: () => ref.invalidate(chatNotificationPermissionProvider),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _turnOn() async {
    final notifier = ref.read(desktopNotifierProvider);
    if (!await notifier.requestPermission()) {
      await notifier.openSystemSettings();
    }
    ref.invalidate(chatNotificationPermissionProvider);
  }

  @override
  Widget build(BuildContext context) {
    final wanted = ref.watch(
      appSettingsProvider.select((s) => s.chatNotifications),
    );
    final granted = ref.watch(chatNotificationPermissionProvider).value;
    final dismissed = ref.watch(chatNotificationWarningDismissedProvider);
    if (!wanted || granted != false || dismissed) {
      return const SizedBox.shrink();
    }
    final l = AppL10n.of(context);
    final c = context.colors;
    final s = context.spacing;
    return Container(
      decoration: BoxDecoration(
        // A light warning tint over the surface, in both themes.
        color: Color.alphaBlend(c.warning.withValues(alpha: 0.12), c.surface),
        border: Border(bottom: context.hairlineSide),
      ),
      padding: EdgeInsets.symmetric(horizontal: s.xl3, vertical: s.md),
      child: Row(
        children: [
          Icon(LucideIcons.bellOff300, color: c.warning, size: s.xl4),
          SizedBox(width: s.lg),
          Expanded(
            child: Text(
              l.chatNotificationsBlocked,
              style: context.typography.secondary.copyWith(
                color: c.textPrimary,
              ),
            ),
          ),
          SizedBox(width: s.lg),
          AppButton.outlinedNeutral(
            size: AppButtonSize.small,
            onPressed: _turnOn,
            child: Text(l.chatNotificationsAllow),
          ),
          IconButton(
            tooltip: l.chatDismiss,
            onPressed: () =>
                ref
                        .read(chatNotificationWarningDismissedProvider.notifier)
                        .state =
                    true,
            icon: Icon(LucideIcons.x300, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
