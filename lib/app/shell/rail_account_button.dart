import 'package:flutter/material.dart';

import '../../core/domain/entities/account.dart';
import '../../core/domain/value_objects/provider_type.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/badges.dart';
import '../../core/widgets/hover_surface.dart';
import '../../core/widgets/unread_badge.dart';

/// Single account button in the navigation rail (design §8, specs S3.1, S3.2).
/// Displays [ProviderBadge], provider/handle label, active indicator,
/// and unread chat badge for ZenTao.
class RailAccountButton extends StatelessWidget {
  const RailAccountButton({
    super.key,
    required this.account,
    required this.isSelected,
    required this.hasDuplicateProvider,
    required this.onTap,
    this.unreadCount = 0,
  });

  final Account account;
  final bool isSelected;
  final bool hasDuplicateProvider;
  final VoidCallback onTap;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final r = context.radii;

    final label = hasDuplicateProvider
        ? account.handle
        : account.providerType.displayName;
    final tooltip = '${account.providerType.displayName} · ${account.handle}';
    final showUnread =
        account.providerType == ProviderType.zentao && unreadCount > 0;

    return Semantics(
      button: true,
      selected: isSelected,
      child: Tooltip(
        message: tooltip,
        preferBelow: false,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: s.xxs),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              HoverSurface(
                onTap: onTap,
                selected: isSelected,
                borderRadius: BorderRadius.circular(r.md),
                color: isSelected ? c.selectionFill : Colors.transparent,
                padding: EdgeInsets.symmetric(horizontal: s.xs, vertical: s.xs),
                child: SizedBox(
                  width: context.sizes.railWidth - s.xl,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: context.sizes.railButton,
                            height: context.sizes.railButton,
                            alignment: Alignment.center,
                            child: ProviderBadge(
                              account.providerType,
                              big: true,
                            ),
                          ),
                          if (showUnread)
                            Positioned(
                              top: -s.xs,
                              right: -s.sm,
                              child: UnreadBadge(count: unreadCount),
                            ),
                        ],
                      ),
                      SizedBox(height: s.xxs),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: context.typography.captionSm.copyWith(
                          color: isSelected ? c.accent : c.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isSelected)
                Positioned(
                  left: 0,
                  child: Container(
                    width: 3,
                    height: 24,
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.horizontal(
                        right: Radius.circular(r.xs),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
