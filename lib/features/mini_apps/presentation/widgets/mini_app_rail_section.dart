import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_context_menu.dart';
import '../../../../core/widgets/app_rail_labeled_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/mini_app.dart';
import '../../domain/usecases/move_mini_app.dart';
import '../providers/mini_app_providers.dart';
import 'mini_app_dialog.dart';
import 'mini_app_icon.dart';

/// The rail's middle: one button per mini app (scrolling when they outgrow the
/// rail; dragged to reorder) and the "+" that adds another. Fills the space
/// between the places above and the utilities below.
class MiniAppRailSection extends ConsumerStatefulWidget {
  const MiniAppRailSection({super.key});

  @override
  ConsumerState<MiniAppRailSection> createState() => _MiniAppRailSectionState();
}

class _MiniAppRailSectionState extends ConsumerState<MiniAppRailSection> {
  /// The order just dropped, shown until the database sends it back so the
  /// moved button does not jump back for a frame.
  List<MiniApp>? _dropped;

  Future<void> _move(List<MiniApp> apps, int from, int to) async {
    setState(() => _dropped = MoveMiniApp.reorder(apps, from: from, to: to));
    final saved = await ref
        .read(miniAppControllerProvider.notifier)
        .move(apps, from: from, to: to);
    if (saved.isErr && mounted) setState(() => _dropped = null);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(miniAppsProvider, (_, _) {
      if (_dropped != null) setState(() => _dropped = null);
    });
    final apps =
        _dropped ??
        ref.watch(miniAppsProvider).asData?.value ??
        const <MiniApp>[];
    final showing = ref.watch(miniAppOnScreenProvider);
    final openId = showing ? ref.watch(openMiniAppIdProvider) : null;
    return Expanded(
      child: ReorderableListView(
        buildDefaultDragHandles: false,
        onReorderItem: (from, to) => _move(apps, from, to),
        proxyDecorator: (child, _, _) =>
            Material(type: MaterialType.transparency, child: child),
        footer: AppRailLabeledButton(
          leading: const Icon(LucideIcons.plus300),
          label: AppL10n.of(context).miniAppAddShort,
          tooltip: AppL10n.of(context).miniAppAdd,
          selected: false,
          onTap: () => MiniAppDialog.show(context),
        ),
        children: [
          for (final (i, app) in apps.indexed)
            _HoldToDragListener(
              key: ValueKey(app.id),
              index: i,
              child: _MiniAppRailButton(app: app, selected: app.id == openId),
            ),
        ],
      ),
    );
  }
}

/// Starts a reorder only after the pointer is held still for a moment. The
/// immediate listener starts one on a mouse moving a single pixel while
/// clicked: the click that opens the app is lost, and the list is left
/// mid-drag while the viewport swaps to the mini app, which can wedge an item
/// in its dragging state (it then fails to build and the rail shows an error).
class _HoldToDragListener extends ReorderableDragStartListener {
  const _HoldToDragListener({
    super.key,
    required super.index,
    required super.child,
  });

  /// Shorter than a long press: a deliberate hold, not a wait.
  static const _hold = Duration(milliseconds: 200);

  @override
  MultiDragGestureRecognizer createRecognizer() =>
      DelayedMultiDragGestureRecognizer(delay: _hold, debugOwner: this);
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
    if (ref.read(openMiniAppIdProvider) == app.id) {
      ref.read(appNavProvider.notifier).closeMiniApp();
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
      child: AppRailLabeledButton(
        leading: MiniAppIcon(name: app.name, iconPath: app.iconPath),
        label: app.name,
        selected: selected,
        onTap: () => ref.read(appNavProvider.notifier).showMiniApp(app.id),
      ),
    );
  }
}
