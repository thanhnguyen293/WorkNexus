import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../core/widgets/app_input_decoration.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/saved_filter_providers.dart';

/// Asks for the name to store the current filter under.
class SaveFilterDialog extends ConsumerStatefulWidget {
  const SaveFilterDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => const SaveFilterDialog(),
  );

  @override
  ConsumerState<SaveFilterDialog> createState() => _SaveFilterDialogState();
}

class _SaveFilterDialogState extends ConsumerState<SaveFilterDialog> {
  final _controller = TextEditingController();

  /// The write failure to show inline, if the last attempt didn't stick.
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Closes only on a successful write — a failed save that closed the dialog
  /// would look exactly like a successful one.
  Future<void> _save() async {
    final name = _controller.text;
    if (name.trim().isEmpty || _saving) return;
    final navigator = Navigator.of(context);
    final failed = AppL10n.of(context).actionFailed;
    setState(() {
      _saving = true;
      _error = null;
    });
    final res = await ref
        .read(savedFilterControllerProvider.notifier)
        .saveCurrent(name);
    if (!mounted) return;
    switch (res) {
      case Ok():
        navigator.pop();
      case Err(:final failure):
        setState(() {
          _saving = false;
          _error = failed(failure.message);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final canSave = _controller.text.trim().isNotEmpty && !_saving;
    return AppDialogFrame(
      title: l.saveFilterTitle,
      maxWidth: context.sizes.dialogSm,
      actions: [
        const Spacer(),
        AppButton.textNeutral(
          size: AppButtonSize.small,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        AppButton.filled(
          size: AppButtonSize.small,
          isLoading: _saving,
          onPressed: canSave ? _save : null,
          child: Text(l.save),
        ),
      ],
      child: Padding(
        padding: EdgeInsets.fromLTRB(s.xl3, 0, s.xl3, s.xl3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.saveFilterNameLabel,
              style: context.typography.bodySmStrong.copyWith(
                color: c.textSecondary,
              ),
            ),
            SizedBox(height: s.sm),
            TextField(
              controller: _controller,
              autofocus: true,
              onSubmitted: (_) => _save(),
              onChanged: (_) => setState(() {
                _error = null;
              }),
              style: context.typography.body.copyWith(color: c.textPrimary),
              decoration: appInputDecoration(
                context,
                hint: l.saveFilterNameHint,
                errorText: _error,
              ),
            ),
            if (_error == null) ...[
              SizedBox(height: s.md),
              Text(
                l.saveFilterExistsHint,
                style: context.typography.caption.copyWith(
                  color: c.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
