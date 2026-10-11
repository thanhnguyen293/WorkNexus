import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/hover_surface.dart';

/// The profile's avatar with a camera badge that changes it, when [editable]
/// (the signed-in user's own profile).
class ChatEditableAvatar extends StatelessWidget {
  const ChatEditableAvatar({
    super.key,
    required this.editable,
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  final bool editable;
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!editable) return child;
    final c = context.colors;
    return Tooltip(
      message: tooltip,
      child: HoverSurface(
        onTap: onTap,
        shape: BoxShape.circle,
        semanticLabel: tooltip,
        // The camera badge is the affordance; a tint would dim the photo.
        tintOnHover: false,
        child: Stack(
          children: [
            child,
            Positioned(
              left: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.all(context.spacing.sm),
                decoration: BoxDecoration(
                  color: c.accent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: c.surface,
                    width: context.borders.thick,
                  ),
                ),
                child: Icon(
                  LucideIcons.camera300,
                  size: context.sizes.iconMd,
                  color: c.onAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
