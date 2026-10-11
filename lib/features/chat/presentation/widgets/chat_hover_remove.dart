import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/hover_surface.dart';

/// A removable tile (an own sticker, an added wallpaper): a right-click, or
/// the delete button shown in its corner on hover, calls [onRemove] with
/// where to open the removal menu.
class ChatHoverRemove extends StatelessWidget {
  const ChatHoverRemove({
    super.key,
    required this.tooltip,
    required this.onRemove,
    required this.child,
  });

  final String tooltip;
  final void Function(Offset at) onRemove;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return HoverRegion(
      child: child,
      builder: (context, hovered, child) => GestureDetector(
        onSecondaryTapDown: (d) => onRemove(d.globalPosition),
        child: Stack(
          children: [
            ?child,
            if (hovered)
              Positioned(
                top: 0,
                right: 0,
                child: _RemoveButton(tooltip: tooltip, onRemove: onRemove),
              ),
          ],
        ),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.tooltip, required this.onRemove});

  final String tooltip;
  final void Function(Offset at) onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Its own surface: it sits over a picture.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: context.cardBorder,
        borderRadius: BorderRadius.circular(context.radii.md),
      ),
      child: AppIconButton(
        icon: LucideIcons.trash2300,
        tooltip: tooltip,
        size: AppIconButtonSize.small,
        color: c.error,
        onPressed: () {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          onRemove(box.localToGlobal(Offset(0, box.size.height)));
        },
      ),
    );
  }
}
