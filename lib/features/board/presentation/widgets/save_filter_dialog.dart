import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../saved_filter_providers.dart';

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
          _error = failure.message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(context.radii.md),
      borderSide: BorderSide(color: c.border),
    );
    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.lg),
      ),
      title: Text(
        l.saveFilterTitle,
        style: context.typography.title.copyWith(color: c.textPrimary),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              onSubmitted: (_) => _save(),
              onChanged: (_) => setState(() {}),
              style: context.typography.body.copyWith(color: c.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                labelText: l.saveFilterNameLabel,
                hintText: l.saveFilterNameHint,
                hintStyle: context.typography.body.copyWith(
                  color: c.textTertiary,
                ),
                border: border,
                enabledBorder: border,
                focusedBorder: border.copyWith(
                  borderSide: BorderSide(color: c.accent),
                ),
              ),
            ),
            SizedBox(height: context.spacing.md),
            Text(
              _error ?? l.saveFilterExistsHint,
              style: context.typography.captionSm.copyWith(
                color: _error == null ? c.textTertiary : c.error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        AppButton.textNeutral(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        SizedBox(width: context.spacing.md),
        AppButton.filled(
          isLoading: _saving,
          onPressed: _controller.text.trim().isEmpty || _saving ? null : _save,
          child: Text(l.save),
        ),
      ],
    );
  }
}
