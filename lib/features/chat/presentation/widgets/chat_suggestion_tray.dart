import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_icon_button.dart';

/// Suggestions over the composer's tools (AI replies, stickers): one header
/// line — icon, [label], close — with the suggestions under the label. The
/// icon sits in the column of the tool icons below, and a hairline sets the
/// tray apart from them.
class ChatSuggestionTray extends StatelessWidget {
  const ChatSuggestionTray({
    super.key,
    required this.icon,
    required this.label,
    required this.closeTooltip,
    required this.onClose,
    this.isError = false,
    this.child,
  });

  final IconData icon;
  final String label;
  final String closeTooltip;
  final VoidCallback onClose;

  /// Shows [label] as a failure.
  final bool isError;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final sizes = context.sizes;
    // The tool buttons are controlLg wide after the tools' s.lg padding;
    // centring the icon in that box puts it over theirs.
    final lead = s.lg + (sizes.controlLg - sizes.iconSm) / 2;
    final indent = sizes.iconSm + s.md;
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: context.hairlineSide)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(lead, s.xs, s.lg, s.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: sizes.iconSm, color: c.accent),
                SizedBox(width: s.md),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.caption.copyWith(
                      color: isError ? c.error : c.textSecondary,
                    ),
                  ),
                ),
                AppIconButton(
                  icon: LucideIcons.x300,
                  tooltip: closeTooltip,
                  size: AppIconButtonSize.small,
                  onPressed: onClose,
                ),
              ],
            ),
            if (child case final child?)
              Padding(
                padding: EdgeInsets.only(left: indent),
                child: child,
              ),
          ],
        ),
      ),
    );
  }
}
