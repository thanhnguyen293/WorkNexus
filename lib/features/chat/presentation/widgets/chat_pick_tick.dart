import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';

/// The round tick at the end of a pickable row (people, chats): an empty
/// ring, filled with the accent and a check once [picked].
class ChatPickTick extends StatelessWidget {
  const ChatPickTick({super.key, required this.picked});

  final bool picked;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final size = context.spacing.xl4;
    return AnimatedContainer(
      duration: AppMotion.fast,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: picked ? c.accent : Colors.transparent,
        border: Border.all(
          color: picked ? c.accent : c.borderStrong,
          width: 1.5,
        ),
      ),
      child: picked
          ? Icon(
              LucideIcons.check300,
              size: context.sizes.iconSm,
              color: c.onAccent,
            )
          : null,
    );
  }
}
