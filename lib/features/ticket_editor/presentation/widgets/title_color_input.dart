import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../domain/value_objects/zentao_choices.dart';

/// The title's colour: none or one of ZenTao's swatches (`#rrggbb`).
class TitleColorInput extends StatelessWidget {
  const TitleColorInput({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final size = s.xl5;
    return Wrap(
      spacing: s.sm,
      children: [
        for (final hex in ['', ...zentaoTitleColors])
          HoverSurface(
            onTap: () => onChanged(hex),
            width: size,
            height: size,
            shape: BoxShape.circle,
            // Colours from ZenTao's data, not the theme.
            color: hex.isEmpty ? c.surfaceSubtle : _parse(hex),
            // The ring answers hover: a tint would shift the colour.
            tintOnHover: false,
            border: Border.all(
              color: hex.toLowerCase() == value.toLowerCase()
                  ? c.textPrimary
                  : c.border,
              width: hex.toLowerCase() == value.toLowerCase() ? 2 : 1,
            ),
            hoverBorder: Border.all(
              color: hex.toLowerCase() == value.toLowerCase()
                  ? c.textPrimary
                  : c.borderStrong,
              width: hex.toLowerCase() == value.toLowerCase() ? 2 : 1,
            ),
            child: hex.isEmpty
                ? Icon(LucideIcons.ban300, size: s.xl2, color: c.textTertiary)
                : null,
          ),
      ],
    );
  }
}

Color _parse(String hex) =>
    Color(int.parse('FF${hex.substring(1)}', radix: 16));
