import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/domain/entities/workspace.dart';
import '../../../../core/domain/usecases/rename_workspace.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../core/widgets/app_input_decoration.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../l10n/app_localizations.dart';
import 'workspace_editor_parts.dart';

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
  late final _name = TextEditingController(text: widget.workspace.name);
  late final _code = TextEditingController(text: widget.workspace.shortCode);

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  /// Whether there is a name to save (the personal workspace has none to
  /// edit).
  bool get _canSave =>
      widget.workspace.isPersonal || _name.text.trim().isNotEmpty;

  void _save() {
    final renamed = const RenameWorkspace()(
      WorkspaceRename(
        workspace: widget.workspace.copyWith(
          colorValue: _colorValue,
          iconKey: _iconKey,
        ),
        name: _name.text,
        shortCode: _code.text,
      ),
    );
    switch (renamed) {
      case Ok(:final value):
        Navigator.of(context).pop(value);
      case Err(:final failure):
        showAppSnack(context, failure.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final fieldLabel = context.typography.captionStrong.copyWith(
      color: c.textSecondary,
    );
    return AppDialogFrame(
      title: l.workspaceEditTitle,
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
          onPressed: _canSave ? _save : null,
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
                ListenableBuilder(
                  listenable: _code,
                  builder: (_, _) => WorkspaceBadge(
                    Color(_colorValue),
                    _code.text.trim().isEmpty
                        ? RenameWorkspace.shortCodeOf(_name.text)
                        : _code.text.trim().toUpperCase(),
                    big: true,
                    iconKey: _iconKey,
                  ),
                ),
                SizedBox(width: s.md),
                Expanded(
                  child: widget.workspace.isPersonal
                      ? Text(
                          l.personal,
                          style: context.typography.bodyStrong.copyWith(
                            color: c.textPrimary,
                          ),
                        )
                      : TextField(
                          controller: _name,
                          autofocus: true,
                          maxLength: RenameWorkspace.maxNameLength,
                          style: context.typography.body,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => setState(() {}),
                          decoration: appInputDecoration(
                            context,
                            hint: l.workspaceNameLabel,
                            errorText: _name.text.trim().isEmpty
                                ? l.workspaceNameRequired
                                : null,
                          ).copyWith(counterText: ''),
                        ),
                ),
              ],
            ),
            if (!widget.workspace.isPersonal) SizedBox(height: s.xl2),
            Text(l.workspaceCodeLabel, style: fieldLabel),
            SizedBox(height: s.sm),
            SizedBox(
              width: context.sizes.controlLg * 3,
              child: TextField(
                controller: _code,
                maxLength: RenameWorkspace.maxCodeLength,
                textCapitalization: TextCapitalization.characters,
                style: context.typography.body,
                decoration: appInputDecoration(
                  context,
                  hint: RenameWorkspace.shortCodeOf(_name.text),
                ).copyWith(counterText: ''),
              ),
            ),
            SizedBox(height: s.xl2),
            Text(l.connectionsColor, style: fieldLabel),
            SizedBox(height: s.sm),
            Wrap(
              spacing: s.sm,
              runSpacing: s.sm,
              children: [
                for (final value in workspaceColorChoices)
                  WorkspaceColorChoice(
                    value: value,
                    selected: value == _colorValue,
                    onTap: () => setState(() => _colorValue = value),
                  ),
              ],
            ),
            SizedBox(height: s.xl2),
            Text(l.connectionsIcon, style: fieldLabel),
            SizedBox(height: s.sm),
            WorkspaceIconFilePicker(
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
