import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../navigation/navigation_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import 'quick_settings_panel.dart';

/// Anchored title-bar trigger for the Quick Settings popover.
class QuickSettingsButton extends ConsumerStatefulWidget {
  const QuickSettingsButton({super.key});

  @override
  ConsumerState<QuickSettingsButton> createState() =>
      _QuickSettingsButtonState();
}

class _QuickSettingsButtonState extends ConsumerState<QuickSettingsButton> {
  final _controller = OverlayPortalController();
  final _triggerFocusNode = FocusNode();
  final _panelFocusNode = FocusNode();
  DateTime? _firstTapAt;
  var _tapCount = 0;
  var _isOpen = false;

  static const _debugTapWindow = Duration(milliseconds: 650);

  void _toggle() {
    if (_isOpen) {
      _hideAndRestoreFocus();
      return;
    }

    setState(() => _isOpen = true);
    _controller.show();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.isShowing) {
        _panelFocusNode.requestFocus();
      }
    });
  }

  void _handleTriggerTap() {
    final now = DateTime.now();
    final firstTapAt = _firstTapAt;
    if (firstTapAt == null || now.difference(firstTapAt) > _debugTapWindow) {
      _firstTapAt = now;
      _tapCount = 0;
    }
    _tapCount++;

    if (_tapCount >= 3) {
      _tapCount = 0;
      _firstTapAt = null;
      _openDebugScreen();
      return;
    }

    _toggle();
  }

  void _openDebugScreen() {
    if (_isOpen) {
      _controller.hide();
      setState(() => _isOpen = false);
    }
    ref.read(talkerDebugOpenProvider.notifier).state = true;
  }

  void _hideAndRestoreFocus() {
    _controller.hide();
    setState(() => _isOpen = false);
    _triggerFocusNode.requestFocus();
  }

  KeyEventResult _handlePanelKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _hideAndRestoreFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _triggerFocusNode.dispose();
    _panelFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final triggerSize = context.spacing.xl5 + context.spacing.xs;
    // Positioned from the trigger's layout-time rect rather than a
    // CompositedTransformFollower: nested overlays inside the panel (tooltips,
    // popup menus) need a paint transform during layout, which a follower only
    // establishes at compositing time.
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _controller,
      overlayChildBuilder: (context, info) => _QuickSettingsOverlay(
        anchor: MatrixUtils.transformRect(
          info.childPaintTransform,
          Offset.zero & info.childSize,
        ),
        overlaySize: info.overlaySize,
        onDismiss: _hideAndRestoreFocus,
        child: Focus(
          focusNode: _panelFocusNode,
          onKeyEvent: _handlePanelKeyEvent,
          child: const QuickSettingsPanel(),
        ),
      ),
      child: SizedBox.square(
        key: const ValueKey<String>('quick-settings-trigger'),
        dimension: triggerSize,
        child: Tooltip(
          message: AppL10n.of(context).quickSettings,
          child: Semantics(
            button: true,
            label: AppL10n.of(context).quickSettings,
            child: Ink(
              decoration: BoxDecoration(
                color: _isOpen ? c.selectionFill : null,
                borderRadius: BorderRadius.circular(context.radii.sm),
              ),
              child: InkWell(
                focusNode: _triggerFocusNode,
                onTap: _handleTriggerTap,
                hoverColor: c.surfaceSubtle,
                borderRadius: BorderRadius.circular(context.radii.sm),
                child: Icon(
                  Icons.settings_outlined,
                  size: context.spacing.xl3,
                  color: _isOpen ? c.accent : c.textTertiary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dismiss barrier below the title bar plus the panel, right-aligned under
/// [anchor] and capped to the space left above the bottom edge.
class _QuickSettingsOverlay extends StatelessWidget {
  const _QuickSettingsOverlay({
    required this.anchor,
    required this.overlaySize,
    required this.onDismiss,
    required this.child,
  });

  final Rect anchor;
  final Size overlaySize;
  final VoidCallback onDismiss;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final gap = context.spacing.xs;
    final top = anchor.bottom + gap;
    final maxHeight =
        (overlaySize.height -
                top -
                MediaQuery.paddingOf(context).bottom -
                context.spacing.xs)
            .clamp(context.spacing.none, context.spacing.xl6 * 12.5);
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          top: anchor.bottom,
          child: ModalBarrier(onDismiss: onDismiss),
        ),
        Positioned(
          top: top,
          right: overlaySize.width - anchor.right,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: child,
          ),
        ),
      ],
    );
  }
}
