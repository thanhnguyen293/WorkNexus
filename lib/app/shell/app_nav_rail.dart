import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/value_objects/provider_type.dart';
import '../../core/navigation/navigation_providers.dart';
import '../../core/theme/app_borders.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/tools/tool_registry_provider.dart';
import '../../features/app_update/presentation/widgets/update_rail_button.dart';
import '../../features/chat/presentation/providers/chat_providers.dart';
import '../../features/notifications/presentation/widgets/notifications_rail_button.dart';
import 'rail_account_button.dart';
import 'rail_connect_button.dart';
import 'rail_workspace_button.dart';

/// The 76px left navigation rail for the unified workspace shell (design §8, specs S3).
/// Features workspace button, per-account buttons with duplicate handling,
/// unread badge for ZenTao, notifications, update, dashed connect button,
/// and Ctrl/Cmd+1…9 shortcuts.
class AppNavRail extends ConsumerStatefulWidget {
  const AppNavRail({super.key});

  /// The rail's fixed width (76px).
  static double widthOf(BuildContext context) => context.sizes.railWidth;

  @override
  ConsumerState<AppNavRail> createState() => _AppNavRailState();
}

class _AppNavRailState extends ConsumerState<AppNavRail> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    super.dispose();
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final isMetaOrControl =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    if (!isMetaOrControl) return false;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.digit1) {
      ref
          .read(appNavProvider.notifier)
          .selectWorkspaceSection(WorkspaceSection.overview);
      return true;
    }

    final digitIndex = switch (key) {
      LogicalKeyboardKey.digit2 => 0,
      LogicalKeyboardKey.digit3 => 1,
      LogicalKeyboardKey.digit4 => 2,
      LogicalKeyboardKey.digit5 => 3,
      LogicalKeyboardKey.digit6 => 4,
      LogicalKeyboardKey.digit7 => 5,
      LogicalKeyboardKey.digit8 => 6,
      LogicalKeyboardKey.digit9 => 7,
      _ => -1,
    };

    if (digitIndex < 0) return false;

    final sorted = ref.read(sortedActiveAccountsProvider);

    if (digitIndex < sorted.length) {
      final account = sorted[digitIndex];
      final registry = ref.read(toolRegistryProvider);
      final module = registry[account.providerType];
      if (module != null) {
        ref
            .read(appNavProvider.notifier)
            .selectAccount(account.id, module: module);
        return true;
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final nav = ref.watch(appNavProvider);
    final registry = ref.watch(toolRegistryProvider);
    final unreadTotal = ref.watch(chatUnreadTotalProvider);
    final sorted = ref.watch(sortedActiveAccountsProvider);

    final providerCounts = <ProviderType, int>{};
    for (final a in sorted) {
      providerCounts[a.providerType] =
          (providerCounts[a.providerType] ?? 0) + 1;
    }

    return Container(
      width: context.sizes.railWidth,
      decoration: BoxDecoration(
        color: c.titleBar,
        border: Border(right: context.hairlineSide),
      ),
      padding: EdgeInsets.symmetric(vertical: s.md),
      child: Column(
        children: [
          const RailWorkspaceButton(),
          Divider(height: s.lg, indent: s.md, endIndent: s.md, color: c.border),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: sorted.length,
              itemBuilder: (context, i) {
                final account = sorted[i];
                final isSelected = switch (nav.rail) {
                  AccountTarget(:final accountId) => accountId == account.id,
                  WorkspaceTarget() => false,
                };
                final hasDuplicate =
                    (providerCounts[account.providerType] ?? 0) > 1;
                final module = registry[account.providerType];

                return RailAccountButton(
                  account: account,
                  isSelected: isSelected,
                  hasDuplicateProvider: hasDuplicate,
                  unreadCount: account.providerType == ProviderType.zentao
                      ? unreadTotal
                      : 0,
                  onTap: () {
                    if (module != null) {
                      ref
                          .read(appNavProvider.notifier)
                          .selectAccount(account.id, module: module);
                    }
                  },
                );
              },
            ),
          ),
          Divider(height: s.md, indent: s.md, endIndent: s.md, color: c.border),
          const NotificationsRailButton(),
          const UpdateRailButton(),
          SizedBox(height: s.xs),
          const RailConnectButton(),
        ],
      ),
    );
  }
}
