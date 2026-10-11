import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/workspace.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';

class WorkspaceEditorDialog extends StatefulWidget {
  const WorkspaceEditorDialog({super.key, required this.workspace});

  final Workspace workspace;

  @override
  State<WorkspaceEditorDialog> createState() => _WorkspaceEditorDialogState();
}

class _WorkspaceEditorDialogState extends State<WorkspaceEditorDialog> {
  static const _maxIconBytes = 256 * 1024;

  late int _colorValue = widget.workspace.colorValue;
  late String _iconKey = widget.workspace.iconKey;
  String? _iconFileName;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final fieldLabel = context.typography.captionStrong.copyWith(
      color: c.textSecondary,
    );
    return AppDialogFrame(
      title: l.connectionsWorkspaceStyle,
      maxWidth: context.sizes.dialogMd,
      actions: [
        const Spacer(),
        AppButton.textNeutral(
          size: AppButtonSize.small,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        AppButton.filled(
          size: AppButtonSize.small,
          onPressed: () => Navigator.of(context).pop(
            widget.workspace.copyWith(
              colorValue: _colorValue,
              iconKey: _iconKey,
            ),
          ),
          child: Text(l.save),
        ),
      ],
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(s.xl3, 0, s.xl3, s.xl3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                WorkspaceBadge(
                  Color(_colorValue),
                  widget.workspace.shortCode,
                  big: true,
                  iconKey: _iconKey,
                ),
                SizedBox(width: s.md),
                Expanded(
                  child: Text(
                    widget.workspace.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.bodyStrong.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: s.xl2),
            Text(l.connectionsColor, style: fieldLabel),
            SizedBox(height: s.sm),
            Wrap(
              spacing: s.sm,
              runSpacing: s.sm,
              children: [
                for (final value in workspaceColorChoices)
                  _ColorChoice(
                    value: value,
                    selected: value == _colorValue,
                    onTap: () => setState(() => _colorValue = value),
                  ),
              ],
            ),
            SizedBox(height: s.xl2),
            Text(l.connectionsIcon, style: fieldLabel),
            SizedBox(height: s.sm),
            _IconFilePicker(
              colorValue: _colorValue,
              shortCode: widget.workspace.shortCode,
              iconKey: _iconKey,
              fileName: _iconFileName,
              onPick: _pickIconFile,
              onClear: workspaceIconImageBytes(_iconKey) == null
                  ? null
                  : () => setState(() {
                      _iconKey = 'briefcase';
                      _iconFileName = null;
                    }),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickIconFile() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.length > _maxIconBytes) {
      showAppSnack(
        context,
        AppL10n.of(context).connectionsIconTooLarge,
        isError: true,
      );
      return;
    }

    final mime = _mimeType(file.name);
    setState(() {
      _iconKey = 'data:$mime;base64,${base64Encode(bytes)}';
      _iconFileName = file.name;
    });
  }

  String _mimeType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/png';
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return HoverSurface(
      onTap: onTap,
      width: context.sizes.controlSm + context.spacing.sm,
      height: context.sizes.controlSm,
      semanticLabel: '#${value.toRadixString(16).padLeft(8, '0').substring(2)}',
      selected: selected,
      color: Color(value),
      borderRadius: BorderRadius.circular(context.radii.sm),
      // The outline answers hover, not a tint: a tint would shift the colour.
      tintOnHover: false,
      border: Border.all(
        color: selected ? c.textPrimary : c.border,
        width: selected ? 2 : 1,
      ),
      hoverBorder: Border.all(
        color: selected ? c.textPrimary : c.borderStrong,
        width: selected ? 2 : 1,
      ),
    );
  }
}

class _IconFilePicker extends StatelessWidget {
  const _IconFilePicker({
    required this.colorValue,
    required this.shortCode,
    required this.iconKey,
    required this.fileName,
    required this.onPick,
    required this.onClear,
  });

  final int colorValue;
  final String shortCode;
  final String iconKey;
  final String? fileName;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final hasImage = workspaceIconImageBytes(iconKey) != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(context.radii.md),
        border: Border.all(color: c.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(context.spacing.md),
        child: Row(
          children: [
            WorkspaceBadge(
              Color(colorValue),
              shortCode,
              big: true,
              iconKey: iconKey,
            ),
            SizedBox(width: context.spacing.md),
            Expanded(
              child: Text(
                hasImage
                    ? (fileName ?? l.connectionsCustomIconSelected)
                    : l.connectionsNoFileSelected,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.secondary.copyWith(
                  color: hasImage ? c.textPrimary : c.textTertiary,
                ),
              ),
            ),
            SizedBox(width: context.spacing.md),
            AppButton.outlinedNeutral(
              size: AppButtonSize.small,
              onPressed: onPick,
              child: Text(l.connectionsChooseFile),
            ),
            if (onClear != null) ...[
              SizedBox(width: context.spacing.sm),
              AppIconButton(
                icon: LucideIcons.x300,
                tooltip: l.connectionsRemoveCustomIcon,
                size: AppIconButtonSize.small,
                onPressed: onClear,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
