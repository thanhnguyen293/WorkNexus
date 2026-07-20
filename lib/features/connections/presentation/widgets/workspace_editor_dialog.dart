import 'package:flutter/material.dart';

import '../../../../core/domain/entities/workspace.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/badges.dart';

class WorkspaceEditorDialog extends StatefulWidget {
  const WorkspaceEditorDialog({super.key, required this.workspace});

  final Workspace workspace;

  @override
  State<WorkspaceEditorDialog> createState() => _WorkspaceEditorDialogState();
}

class _WorkspaceEditorDialogState extends State<WorkspaceEditorDialog> {
  late int _colorValue = widget.workspace.colorValue;
  late String _iconKey = widget.workspace.iconKey;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      title: const Text('Workspace style'),
      content: SizedBox(
        width: 360,
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
              style: context.typography.caption.copyWith(color: c.textTertiary),
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
              style: context.typography.caption.copyWith(color: c.textTertiary),
            ),
            SizedBox(height: context.spacing.sm),
            Wrap(
              spacing: context.spacing.sm,
              runSpacing: context.spacing.sm,
              children: [
                for (final key in workspaceIconKeys)
                  _IconChoice(
                    iconKey: key,
                    selected: key == _iconKey,
                    onTap: () => setState(() => _iconKey = key),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            widget.workspace.copyWith(
              colorValue: _colorValue,
              iconKey: _iconKey,
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
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

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.iconKey,
    required this.selected,
    required this.onTap,
  });

  final String iconKey;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.radii.sm),
      child: Container(
        width: 42,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.selectionFill : c.surface,
          borderRadius: BorderRadius.circular(context.radii.sm),
          border: Border.all(color: selected ? c.accent : c.border),
        ),
        child: Icon(
          workspaceIconData(iconKey),
          size: 17,
          color: selected ? c.accent : c.textSecondary,
        ),
      ),
    );
  }
}
