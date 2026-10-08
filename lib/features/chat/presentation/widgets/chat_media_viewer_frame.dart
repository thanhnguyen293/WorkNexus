import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';

/// Share of the window the image and video viewers take: centred over the
/// dimmed chat rather than covering it.
const double _kWidthFactor = 0.8;
const double _kHeightFactor = 0.85;

/// How much the chat behind the viewer is dimmed.
const double kChatViewerBarrierAlpha = 0.6;

/// The image and video viewers' frame: a dark, rounded panel centred in the
/// window, about four fifths of its size, around the bar and the media.
class ChatMediaViewerFrame extends StatelessWidget {
  const ChatMediaViewerFrame({
    super.key,
    required this.child,
    this.expanded = false,
  });

  final Widget child;

  /// Fills the window (a video played full screen).
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final s = context.spacing;
    if (expanded) {
      return Dialog.fullscreen(
        backgroundColor: context.colors.scrim,
        child: child,
      );
    }
    return Dialog(
      insetPadding: EdgeInsets.all(s.xl3),
      clipBehavior: Clip.antiAlias,
      backgroundColor: context.colors.scrim,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.lg),
      ),
      child: SizedBox(
        width: math.max(size.width * _kWidthFactor, s.xl6 * 12),
        height: math.max(size.height * _kHeightFactor, s.xl6 * 9),
        child: child,
      ),
    );
  }
}
