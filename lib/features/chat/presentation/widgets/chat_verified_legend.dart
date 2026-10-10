import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/chat_role.dart';
import 'chat_labels.dart';

/// What the "verified" checks mean, shown on hovering one: a row per check
/// colour (gold, violet, blue) listing its roles, then the roles with no
/// check. The viewed user's [role] is highlighted.
class ChatVerifiedLegend extends StatelessWidget {
  const ChatVerifiedLegend({super.key, required this.role});

  /// The viewed user's role code.
  final String role;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    return IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.only(left: s.md, bottom: s.sm),
            child: Text(
              l.chatRoleBadges,
              style: context.typography.captionStrong.copyWith(
                color: c.textSecondary,
              ),
            ),
          ),
          for (final rank in ChatRoleRank.values.reversed)
            _Row(
              color: chatRankColor(context, rank),
              roles: chatRoleCodesOf(rank),
              current: role,
            ),
          _Row(
            color: null,
            label: l.chatRoleNoBadge,
            roles: [ChatRole.dev.name, ChatRole.qa.name],
            current: role,
          ),
        ],
      ),
    );
  }
}

/// One check colour (or none, with its [label]) and the roles it marks.
class _Row extends StatelessWidget {
  const _Row({
    required this.color,
    required this.roles,
    required this.current,
    this.label,
  });

  final Color? color;
  final List<String> roles;
  final String current;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final text = context.typography.bodySm.copyWith(color: c.textPrimary);
    final check = color;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.sm),
      child: Row(
        children: [
          if (check != null)
            Icon(Icons.verified_rounded, size: s.xl3, color: check)
          else
            Icon(LucideIcons.minus300, size: s.xl3, color: c.textTertiary),
          SizedBox(width: s.md),
          // Wraps when the window is narrow rather than overflowing.
          Flexible(
            child: Text.rich(
              TextSpan(
                style: text,
                children: [
                  if (label case final label?) TextSpan(text: '$label: '),
                  for (final (i, r) in roles.indexed) ...[
                    if (i > 0) const TextSpan(text: ', '),
                    if (r == current.toLowerCase())
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: s.sm,
                            vertical: s.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: c.selectionFill,
                            borderRadius: BorderRadius.circular(
                              context.radii.sm,
                            ),
                          ),
                          child: Text(
                            chatRoleLabel(context, r),
                            style: text.copyWith(
                              color: c.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                    else
                      TextSpan(text: chatRoleLabel(context, r)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
