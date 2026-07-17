import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import 'quick_settings_panel.dart';

/// Anchored title-bar trigger for the Quick Settings popover.
class QuickSettingsButton extends StatefulWidget {
  const QuickSettingsButton({super.key});

  @override
  State<QuickSettingsButton> createState() => _QuickSettingsButtonState();
}

class _QuickSettingsButtonState extends State<QuickSettingsButton> {
  final _controller = OverlayPortalController();
  final _layerLink = LayerLink();
  final _triggerFocusNode = FocusNode();
  final _panelFocusNode = FocusNode();
  var _isOpen = false;

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

  double _panelMaxHeight(BuildContext context) {
    final renderObject = _triggerFocusNode.context?.findRenderObject();
    final trigger = renderObject is RenderBox ? renderObject : null;
    if (trigger == null) {
      return 0;
    }

    final triggerBottom =
        trigger.localToGlobal(Offset.zero).dy + trigger.size.height;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final followerOffset = context.spacing.xs;
    final bottomSpacing = context.spacing.xs;
    final remainingHeight =
        MediaQuery.sizeOf(context).height -
        triggerBottom -
        followerOffset -
        bottomInset -
        bottomSpacing;

    return remainingHeight.clamp(0, context.spacing.xl6 * 12.5);
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
    return OverlayPortal(
      controller: _controller,
      overlayChildBuilder: (context) => Stack(
        fit: StackFit.expand,
        children: [
          ModalBarrier(onDismiss: _hideAndRestoreFocus),
          Positioned(
            left: context.spacing.none,
            top: context.spacing.none,
            child: CompositedTransformFollower(
              link: _layerLink,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: Offset(context.spacing.none, context.spacing.xs),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: _panelMaxHeight(context),
                ),
                child: Focus(
                  focusNode: _panelFocusNode,
                  onKeyEvent: _handlePanelKeyEvent,
                  child: const QuickSettingsPanel(),
                ),
              ),
            ),
          ),
        ],
      ),
      child: CompositedTransformTarget(
        link: _layerLink,
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
                  onTap: _toggle,
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
      ),
    );
  }
}
