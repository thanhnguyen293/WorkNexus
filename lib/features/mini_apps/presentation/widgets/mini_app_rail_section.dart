import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_context_menu.dart';
import '../../../../core/widgets/app_rail_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/mini_app.dart';
import '../providers/mini_app_providers.dart';
import 'mini_app_dialog.dart';
import 'mini_app_icon.dart';

/// The rail's middle: one button per mini app (scrolling when they outgrow the
/// rail) and the "+" that adds another. Fills the space between the places
/// above and the utilities below.
class MiniAppRailSection extends ConsumerWidget {
  const MiniAppRailSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(miniAppsProvider).asData?.value ?? const <MiniApp>[];
    final showing = ref.watch(selectedMainViewProvider) == MainView.miniApp;
    final openId = showing ? ref.watch(openMiniAppIdProvider) : null;
    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          children: [
            for (final app in apps)
              _MiniAppRailButton(app: app, selected: app.id == openId),
            AppRailButton(
              icon: LucideIcons.plus300,
              label: AppL10n.of(context).miniAppAdd,
              selected: false,
              onTap: () => MiniAppDialog.show(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniAppRailButton extends ConsumerWidget {
  const _MiniAppRailButton({required this.app, required this.selected});

  final MiniApp app;
  final bool selected;

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final l = AppL10n.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l.miniAppRemoveTitle(app.name),
      message: l.miniAppRemoveMessage,
      confirmLabel: l.miniAppRemove,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    if (ref.read(appNavProvider).miniAppId == app.id) {
      ref.read(appNavProvider.notifier).show(MainView.dashboard);
    }
    await ref.read(miniAppControllerProvider.notifier).remove(app.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: (details) async {
        final picked = await showAppContextMenu(
          context,
          at: details.globalPosition,
          entries: [
            AppMenuEntry(icon: LucideIcons.pencil300, label: l.miniAppEdit),
            AppMenuEntry(
              icon: LucideIcons.trash2300,
              label: l.miniAppRemove,
              destructive: true,
              dividerBefore: true,
            ),
          ],
        );
        if (!context.mounted) return;
        if (picked == 0) {
          await MiniAppDialog.show(context, existing: app);
        } else if (picked == 1) {
          await _remove(context, ref);
        }
      },
      child: AppRailButton(
        leading: MiniAppIcon(name: app.name, iconPath: app.iconPath),
        label: app.name,
        selected: selected,
        onTap: () => ref.read(appNavProvider.notifier).showMiniApp(app.id),
      ),
    );
  }
}
