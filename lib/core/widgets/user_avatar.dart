import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Theme-aware avatar used by the navigation menu and profile dialog.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    required this.diameter,
    this.imageUrl,
  });

  final String name;
  final double diameter;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: diameter / 2,
      backgroundColor: context.colors.selectionFill,
      child: Text(
        name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase(),
        // The initial scales down with a small avatar (a timeline's) so it
        // sits inside the circle instead of filling it.
        style: context.typography.title.copyWith(
          color: context.colors.accent,
          fontSize: math.min(
            context.typography.title.fontSize ?? 16,
            diameter * 0.45,
          ),
        ),
      ),
    );
    final url = imageUrl;
    if (url == null || url.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: url,
      width: diameter,
      height: diameter,
      imageBuilder: (context, image) =>
          CircleAvatar(radius: diameter / 2, backgroundImage: image),
      placeholder: (context, url) => fallback,
      errorWidget: (context, url, error) => fallback,
    );
  }
}
