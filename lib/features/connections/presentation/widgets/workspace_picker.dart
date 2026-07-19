import 'package:flutter/material.dart';

import '../../../../core/domain/entities/workspace.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// The workspace dropdown shared by the connection dialogs: lists existing
/// workspaces plus a "New workspace…" entry ([newValue]).
class WorkspacePicker extends StatelessWidget {
  const WorkspacePicker({
    super.key,
    required this.workspaces,
    required this.value,
    required this.newValue,
    required this.onChanged,
  });

  final List<Workspace> workspaces;
  final String? value;
  final String newValue;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.workspace,
          style: context.typography.captionStrong.copyWith(
            color: c.textSecondary,
          ),
        ),
        SizedBox(height: context.spacing.xs),
        Container(
          padding: EdgeInsets.symmetric(horizontal: context.spacing.lg),
          decoration: BoxDecoration(
            color: c.surfaceSubtle,
            borderRadius: BorderRadius.circular(context.radii.md),
            border: Border.all(color: c.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: c.surfaceSubtle,
              style: context.typography.body.copyWith(color: c.textPrimary),
              items: [
                for (final w in workspaces)
                  DropdownMenuItem<String>(
                    value: w.id,
                    child: Text(w.isPersonal ? l.personal : w.name),
                  ),
                DropdownMenuItem<String>(
                  value: newValue,
                  child: Text(
                    l.newWorkspaceOption,
                    style: context.typography.body.copyWith(color: c.accent),
                  ),
                ),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
