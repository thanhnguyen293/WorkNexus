import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../core/domain/entities/workspace.dart';
import '../../../../core/domain/repositories/workspace_repository.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import 'workspace_chips.dart';

/// Dialog to create a new workspace and automatically join/switch into it.
class CreateWorkspaceDialog extends ConsumerStatefulWidget {
  const CreateWorkspaceDialog({super.key});

  static Future<Workspace?> show(BuildContext context) {
    return showDialog<Workspace>(
      context: context,
      builder: (_) => const CreateWorkspaceDialog(),
    );
  }

  @override
  ConsumerState<CreateWorkspaceDialog> createState() =>
      _CreateWorkspaceDialogState();
}

class _CreateWorkspaceDialogState extends ConsumerState<CreateWorkspaceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  int _colorValue = workspaceColorChoices.first;
  String _iconKey = 'briefcase';
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged(String val) {
    if (_codeCtrl.text.isEmpty || _codeCtrl.text.length <= 4) {
      final trimmed = val.trim();
      if (trimmed.isNotEmpty) {
        final words = trimmed.split(RegExp(r'\s+'));
        final code = words.length > 1
            ? words.take(3).map((w) => w[0]).join().toUpperCase()
            : trimmed.takeLeadingLetters(3).toUpperCase();
        _codeCtrl.text = code;
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final name = _nameCtrl.text.trim();
    var code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      code = name.takeLeadingLetters(3).toUpperCase();
    }

    final id = 'ws_${DateTime.now().millisecondsSinceEpoch}';
    final workspace = Workspace(
      id: id,
      name: name,
      shortCode: code,
      colorValue: _colorValue,
      iconKey: _iconKey,
    );

    try {
      await getIt<WorkspaceRepository>().createWorkspace(workspace);
      if (!mounted) return;

      // Auto-join this space immediately
      ref.read(activeWorkspaceIdProvider.notifier).state = workspace.id;
      ref.read(filterStateProvider.notifier).setWorkspace(workspace.id);

      Navigator.of(context).pop(workspace);
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final fieldLabel = context.typography.captionStrong.copyWith(
      color: c.textSecondary,
    );

    return AppDialogFrame(
      title: 'Create Workspace',
      maxWidth: context.sizes.dialogMd,
      actions: [
        const Spacer(),
        AppButton.textNeutral(
          size: AppButtonSize.small,
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton.filled(
          size: AppButtonSize.small,
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create & Join'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(s.xl3, 0, s.xl3, s.xl3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: s.xs),
                    child: WorkspaceBadge(
                      Color(_colorValue),
                      _codeCtrl.text.isNotEmpty ? _codeCtrl.text : 'WS',
                      big: true,
                      iconKey: _iconKey,
                    ),
                  ),
                  SizedBox(width: s.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Workspace Name', style: fieldLabel),
                        SizedBox(height: s.xs),
                        TextFormField(
                          controller: _nameCtrl,
                          autofocus: true,
                          style: context.typography.body,
                          decoration: InputDecoration(
                            hintText: 'e.g. Acme Corporation, Frontend Team',
                            hintStyle: context.typography.body.copyWith(
                              color: c.textTertiary,
                            ),
                            filled: true,
                            fillColor: c.surfaceSubtle,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                context.radii.sm,
                              ),
                              borderSide: BorderSide(color: c.border),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: s.md,
                              vertical: s.sm,
                            ),
                          ),
                          onChanged: _onNameChanged,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Name is required'
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: s.lg),
              Text('Short Code (2-4 characters)', style: fieldLabel),
              SizedBox(height: s.xs),
              TextFormField(
                controller: _codeCtrl,
                style: context.typography.monoSm,
                maxLength: 4,
                decoration: InputDecoration(
                  hintText: 'e.g. ACM',
                  hintStyle: context.typography.monoSm.copyWith(
                    color: c.textTertiary,
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: c.surfaceSubtle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(context.radii.sm),
                    borderSide: BorderSide(color: c.border),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: s.md,
                    vertical: s.sm,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              SizedBox(height: s.lg),
              Text('Workspace Color', style: fieldLabel),
              SizedBox(height: s.sm),
              Wrap(
                spacing: s.sm,
                runSpacing: s.sm,
                children: [
                  for (final val in workspaceColorChoices)
                    WorkspaceColorChip(
                      value: val,
                      selected: val == _colorValue,
                      onTap: () => setState(() => _colorValue = val),
                    ),
                ],
              ),
              SizedBox(height: s.lg),
              Text('Icon Type', style: fieldLabel),
              SizedBox(height: s.sm),
              Wrap(
                spacing: s.sm,
                runSpacing: s.sm,
                children: [
                  for (final key in const [
                    'briefcase',
                    'building',
                    'rocket',
                    'code',
                    'globe',
                    'zap',
                  ])
                    WorkspaceIconChip(
                      iconKey: key,
                      selected: key == _iconKey,
                      colorValue: _colorValue,
                      onTap: () => setState(() => _iconKey = key),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _StringHelper on String {
  String takeLeadingLetters(int n) {
    final chars = replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    return chars.length > n ? chars.substring(0, n) : chars;
  }
}
