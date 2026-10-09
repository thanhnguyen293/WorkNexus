import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// A labelled form field; a required one is starred, and [missing] shows it
/// needs filling in.
class EditorField extends StatelessWidget {
  const EditorField({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
    this.missing = false,
  });

  final String label;
  final Widget child;
  final bool required;
  final bool missing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Padding(
      padding: EdgeInsets.only(bottom: s.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              text: label,
              children: [
                if (required)
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: c.error),
                  ),
              ],
            ),
            style: context.typography.captionStrong.copyWith(
              color: c.textSecondary,
            ),
          ),
          SizedBox(height: s.sm),
          child,
          if (missing) ...[
            SizedBox(height: s.xs),
            Text(
              AppL10n.of(context).formRequired,
              style: context.typography.caption.copyWith(color: c.error),
            ),
          ],
        ],
      ),
    );
  }
}
