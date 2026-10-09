import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// Takes the composer's place in a chat the user may not post in.
class ChatReadOnlyBar extends StatelessWidget {
  const ChatReadOnlyBar({super.key, required this.adminsOnly});

  /// The chat lets only its admins post (else a list of people does).
  final bool adminsOnly;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: s.xl3, vertical: s.xl3),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: context.hairlineSide),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsLight.lockSimple,
            size: s.xl3,
            color: c.textTertiary,
          ),
          SizedBox(width: s.md),
          Flexible(
            child: Text(
              adminsOnly ? l.chatReadOnlyAdmins : l.chatReadOnly,
              textAlign: TextAlign.center,
              style: context.typography.secondary.copyWith(
                color: c.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
