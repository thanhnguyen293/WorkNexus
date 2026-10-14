import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hover_surface.dart';

/// A field value in the detail table that goes somewhere when tapped: accent
/// text that underlines on hover, or a spinner while [busy].
class DetailFieldLink extends StatelessWidget {
  const DetailFieldLink({
    super.key,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return HoverRegion(
      // The underline is the hover cue, like the other text links here.
      builder: (context, hovered, _) => HoverSurface(
        onTap: busy ? null : onTap,
        tintOnHover: false,
        borderRadius: BorderRadius.circular(context.radii.sm),
        child: busy
            ? SizedBox.square(
                dimension: context.sizes.iconSm,
                child: const CircularProgressIndicator(),
              )
            : Text(
                label,
                textAlign: TextAlign.right,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: context.typography.secondary.copyWith(
                  color: c.accent,
                  decoration: hovered ? TextDecoration.underline : null,
                  decorationColor: c.accent,
                ),
              ),
      ),
    );
  }
}
