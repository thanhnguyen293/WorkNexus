import 'package:flutter/material.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../core/widgets/app_input_decoration.dart';
import '../../../../l10n/app_localizations.dart';
import 'chat_snack.dart';

/// Asks for a name — a group's, a category's — and saves it with [onSave],
/// closing once that succeeds and showing its failure otherwise.
class ChatNameDialog extends StatefulWidget {
  const ChatNameDialog({
    super.key,
    required this.title,
    required this.initial,
    required this.hint,
    required this.onSave,
    this.extra = const [],
  });

  final String title;
  final String initial;
  final String hint;
  final Future<Result<void>> Function(String name) onSave;

  /// Shown under the field (e.g. names to pick from); each gets the field's
  /// controller.
  final List<Widget Function(TextEditingController name)> extra;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String initial,
    required String hint,
    required Future<Result<void>> Function(String name) onSave,
    List<Widget Function(TextEditingController name)> extra = const [],
  }) => showDialog<void>(
    context: context,
    builder: (_) => ChatNameDialog(
      title: title,
      initial: initial,
      hint: hint,
      onSave: onSave,
      extra: extra,
    ),
  );

  @override
  State<ChatNameDialog> createState() => _ChatNameDialogState();
}

class _ChatNameDialogState extends State<ChatNameDialog> {
  late final _name = TextEditingController(text: widget.initial)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final result = await widget.onSave(_name.text);
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.of(context).pop();
      case Err(:final failure):
        setState(() => _saving = false);
        showChatFailure(context, failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final l = AppL10n.of(context);
    return AppDialogFrame(
      title: widget.title,
      maxWidth: context.sizes.dialogSm,
      actions: [
        const Spacer(),
        AppButton.textNeutral(
          size: AppButtonSize.small,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.chatCancel),
        ),
        ValueListenableBuilder(
          valueListenable: _name,
          builder: (context, value, _) => AppButton.filled(
            size: AppButtonSize.small,
            isLoading: _saving,
            isDisabled: value.text.trim().isEmpty,
            onPressed: _save,
            child: Text(l.chatSave),
          ),
        ),
      ],
      child: Padding(
        padding: EdgeInsets.fromLTRB(s.xl3, 0, s.xl3, s.xl3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              onSubmitted: (_) => _save(),
              style: context.typography.body.copyWith(
                color: context.colors.textPrimary,
              ),
              decoration: appInputDecoration(context, hint: widget.hint),
            ),
            for (final build in widget.extra) build(_name),
          ],
        ),
      ),
    );
  }
}
