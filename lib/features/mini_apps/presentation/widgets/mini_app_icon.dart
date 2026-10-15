import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_typography.dart';

/// A mini app's icon: its image file, or the first letter of its name when it
/// has none (or the file cannot be read). The letter takes the ink colour of
/// the surrounding [DefaultTextStyle].
class MiniAppIcon extends StatelessWidget {
  const MiniAppIcon({super.key, required this.name, this.iconPath, this.size});

  final String name;
  final String? iconPath;

  /// Defaults to the rail's icon size.
  final double? size;

  @override
  Widget build(BuildContext context) {
    final side = size ?? context.sizes.iconLg;
    final trimmed = name.trim();
    final letter = trimmed.isEmpty
        ? '?'
        : String.fromCharCode(trimmed.runes.first).toUpperCase();
    final fallback = Center(
      child: Text(letter, style: context.typography.titleSm),
    );
    final path = iconPath;
    return SizedBox.square(
      dimension: side,
      child: path == null
          ? fallback
          : ClipRRect(
              borderRadius: BorderRadius.circular(context.radii.sm),
              child: Image.file(
                File(path),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => fallback,
              ),
            ),
    );
  }
}
