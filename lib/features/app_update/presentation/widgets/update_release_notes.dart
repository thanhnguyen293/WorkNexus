import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../../../core/widgets/markdown_text.dart';
import '../../../../l10n/app_localizations.dart';

/// "What's new": the release's GitHub notes in a scrollable box, so long
/// notes do not push the dialog's buttons off screen.
class UpdateReleaseNotes extends StatelessWidget {
  const UpdateReleaseNotes({required this.notes, super.key});

  final String notes;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(title: AppL10n.of(context).updateWhatsNew),
        SizedBox(height: s.xs),
        ConstrainedBox(
          // Half the window, so the buttons stay on screen; the rest scrolls.
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.5,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.surfaceSubtle,
              borderRadius: BorderRadius.circular(context.radii.md),
              border: Border.all(color: c.border),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(s.xl),
              child: MarkdownText(notes, color: c.textPrimary),
            ),
          ),
        ),
      ],
    );
  }
}
