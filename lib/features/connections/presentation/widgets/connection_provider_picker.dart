import 'package:flutter/material.dart';

import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';

/// The providers an account can be connected from, one per tile; [value] is
/// the one whose form shows. Jira is not supported yet: its tile is dimmed and
/// says so on hover.
class ConnectionProviderPicker extends StatelessWidget {
  const ConnectionProviderPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ProviderType value;
  final ValueChanged<ProviderType> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    spacing: context.spacing.md,
    children: [
      for (final p in ProviderType.values)
        Expanded(
          child: _ProviderTile(
            provider: p,
            selected: p == value,
            onTap: p == ProviderType.jira ? null : () => onChanged(p),
          ),
        ),
    ],
  );
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.provider,
    required this.selected,
    required this.onTap,
  });

  final ProviderType provider;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final tile = HoverSurface(
      onTap: onTap,
      selected: selected,
      semanticLabel: provider.displayName,
      padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.lg),
      color: selected ? c.selectionFill : c.surface,
      borderRadius: BorderRadius.circular(context.radii.md),
      border: Border.all(
        color: selected ? c.accent : c.border,
        width: selected ? context.borders.medium : context.borders.hairline,
      ),
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ProviderBadge(provider, big: true),
          SizedBox(width: s.sm),
          Flexible(
            child: Text(
              provider.displayName,
              overflow: TextOverflow.ellipsis,
              style: context.typography.bodySm.copyWith(
                color: selected ? c.textPrimary : c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap != null) return tile;
    return Tooltip(
      message: AppL10n.of(
        context,
      ).connectionsProviderComingSoon(provider.displayName),
      child: Opacity(opacity: 0.5, child: tile),
    );
  }
}
