import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/workspace.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../core/widgets/connection_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import 'workspace_picker.dart';

/// The chrome the ZenTao / GitLab / GitHub connect dialogs share: the provider
/// badge and blurb, the provider's own [fields], the workspace picker (with a
/// name field for a new one), the last error, and Cancel / Connect & sync.
class ConnectionDialogFrame extends StatelessWidget {
  const ConnectionDialogFrame({
    super.key,
    required this.provider,
    required this.title,
    required this.subtitle,
    required this.fields,
    required this.workspaces,
    required this.workspaceId,
    required this.newWorkspaceValue,
    required this.newWorkspace,
    required this.onWorkspaceChanged,
    required this.onNewWorkspaceChanged,
    required this.busy,
    required this.error,
    required this.onConnect,
  });

  final ProviderType provider;
  final String title;
  final String subtitle;
  final List<Widget> fields;
  final List<Workspace> workspaces;
  final String? workspaceId;

  /// The picker value that stands for "create a new workspace".
  final String newWorkspaceValue;
  final TextEditingController newWorkspace;
  final ValueChanged<String?> onWorkspaceChanged;
  final VoidCallback onNewWorkspaceChanged;
  final bool busy;
  final String? error;

  /// Null while the form can't be submitted yet.
  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final error = this.error;
    // No workspace yet: skip the picker; connecting creates a default one.
    final noWorkspace = workspaces.isEmpty;
    return AppDialogFrame(
      title: title,
      maxWidth: context.sizes.dialogMd,
      actions: [
        const Spacer(),
        AppButton.textNeutral(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        AppButton.filled(
          isLoading: busy,
          onPressed: onConnect,
          child: Text(l.connectAndSync),
        ),
      ],
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(s.xl3, 0, s.xl3, s.xl3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProviderBadge(provider, big: true),
                SizedBox(width: s.lg),
                Expanded(
                  child: Text(
                    subtitle,
                    style: context.typography.paragraphSm.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: s.xl3),
            for (final (i, field) in fields.indexed) ...[
              if (i > 0) SizedBox(height: s.lg),
              field,
            ],
            if (!noWorkspace) ...[
              SizedBox(height: s.xl),
              WorkspacePicker(
                workspaces: workspaces,
                value: workspaceId,
                newValue: newWorkspaceValue,
                onChanged: onWorkspaceChanged,
              ),
            ],
            if (!noWorkspace && workspaceId == newWorkspaceValue) ...[
              SizedBox(height: s.lg),
              ConnectionTextField(
                label: l.newWorkspaceName,
                controller: newWorkspace,
                hint: l.newWorkspaceHint,
                onChanged: (_) => onNewWorkspaceChanged(),
                onSubmitted: (_) => onConnect?.call(),
              ),
            ],
            if (error != null) ...[SizedBox(height: s.xl), _ErrorNote(error)],
          ],
        ),
      ),
    );
  }
}

/// Why the last connect attempt failed, under the form.
class _ErrorNote extends StatelessWidget {
  const _ErrorNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: EdgeInsets.all(s.lg),
        decoration: BoxDecoration(
          color: c.mixT(c.error, 0.10),
          borderRadius: BorderRadius.circular(context.radii.md),
          border: Border.all(color: c.mixT(c.error, 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              LucideIcons.circleAlert300,
              size: context.sizes.iconSm,
              color: c.error,
            ),
            SizedBox(width: s.md),
            Expanded(
              child: Text(
                message,
                style: context.typography.bodySm.copyWith(color: c.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
