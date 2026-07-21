import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/domain/entities/workspace.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/badges.dart';

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
    return Dialog(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.all(context.spacing.xl3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.lg),
        side: BorderSide(color: c.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: EdgeInsets.all(context.spacing.xl2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workspace style',
                style: context.typography.titleLg.copyWith(
                  color: c.textPrimary,
                ),
              ),
              SizedBox(height: context.spacing.xl),
              Row(
                children: [
                  WorkspaceBadge(
                    Color(_colorValue),
                    widget.workspace.shortCode,
                    big: true,
                    iconKey: _iconKey,
                  ),
                  SizedBox(width: context.spacing.md),
                  Expanded(
                    child: Text(
                      widget.workspace.name,
                      style: context.typography.bodyStrong.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.spacing.xl2),
              Text(
                'Color',
                style: context.typography.captionStrong.copyWith(
                  color: c.textTertiary,
                ),
              ),
              SizedBox(height: context.spacing.sm),
              Wrap(
                spacing: context.spacing.sm,
                runSpacing: context.spacing.sm,
                children: [
                  for (final value in workspaceColorChoices)
                    _ColorChoice(
                      value: value,
                      selected: value == _colorValue,
                      onTap: () => setState(() => _colorValue = value),
                    ),
                ],
              ),
              SizedBox(height: context.spacing.xl2),
              Text(
                'Icon',
                style: context.typography.captionStrong.copyWith(
                  color: c.textTertiary,
                ),
              ),
              SizedBox(height: context.spacing.sm),
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
              SizedBox(height: context.spacing.xl2),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton.textNeutral(
                    size: AppButtonSize.small,
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  SizedBox(width: context.spacing.sm),
                  AppButton.filled(
                    size: AppButtonSize.small,
                    onPressed: () => Navigator.of(context).pop(
                      widget.workspace.copyWith(
                        colorValue: _colorValue,
                        iconKey: _iconKey,
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickIconFile() async {
    final messenger = ScaffoldMessenger.of(context);
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.length > _maxIconBytes) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Icon file must be 256 KB or smaller.')),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.radii.sm),
      child: Container(
        width: 34,
        height: 28,
        decoration: BoxDecoration(
          color: Color(value),
          borderRadius: BorderRadius.circular(context.radii.sm),
          border: Border.all(
            color: selected ? c.textPrimary : c.border,
            width: selected ? 2 : 1,
          ),
        ),
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
                    ? (fileName ?? 'Custom icon selected')
                    : 'No file selected',
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
              child: const Text('Choose file'),
            ),
            if (onClear != null) ...[
              SizedBox(width: context.spacing.sm),
              IconButton(
                tooltip: 'Remove custom icon',
                visualDensity: VisualDensity.compact,
                onPressed: onClear,
                icon: Icon(Icons.close, size: 16, color: c.textTertiary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
