import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/privacy_mask.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/chat_privacy_part.dart';
import 'chat_privacy_mask.dart';

/// One labelled detail in a profile section: a tinted icon tile, the label
/// over the value, and (for contacts) a copy button.
class ChatProfileInfoRow extends StatelessWidget {
  const ChatProfileInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.copyable = false,
    this.privacyPart,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Shows a copy button (emails, phone numbers, handles).
  final bool copyable;

  /// Shows the value as dots while the privacy mode hides this part.
  final ChatPrivacyPart? privacyPart;

  Future<void> _copy(BuildContext context) async {
    final copied = AppL10n.of(context).chatCopied;
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) showAppSnack(context, copied);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final valueStyle = context.typography.body.copyWith(color: c.textPrimary);
    final text = SelectableText(value, style: valueStyle);
    return Padding(
      padding: EdgeInsets.fromLTRB(s.xl, s.md, s.sm, s.md),
      child: Row(
        children: [
          Container(
            width: s.xl5 + s.xs,
            height: s.xl5 + s.xs,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(context.radii.sm),
            ),
            child: Icon(icon, size: context.sizes.iconMd, color: c.accent),
          ),
          SizedBox(width: s.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.typography.caption.copyWith(
                    color: c.textTertiary,
                  ),
                ),
                switch (privacyPart) {
                  null => text,
                  final part => ChatPrivacyMask(
                    part: part,
                    mask: Text(kPrivacyMaskText, style: valueStyle),
                    child: text,
                  ),
                },
              ],
            ),
          ),
          if (copyable)
            AppIconButton(
              icon: LucideIcons.copy300,
              size: AppIconButtonSize.small,
              tooltip: AppL10n.of(context).chatProfileCopy(label),
              onPressed: () => _copy(context),
            ),
        ],
      ),
    );
  }
}
