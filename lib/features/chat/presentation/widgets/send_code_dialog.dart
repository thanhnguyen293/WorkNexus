import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../core/widgets/app_input_decoration.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/send_code_message.dart';

/// A code snippet to send, as written in [SendCodeDialog].
typedef ChatCodeDraft = ({String code, String language, String name});

/// The official client's "send code" dialog: an optional name, a language
/// and the code itself. Resolves to the draft on Send (or Cmd/Ctrl+Enter),
/// null when closed; the composer sends it.
class SendCodeDialog extends StatefulWidget {
  const SendCodeDialog({super.key});

  static Future<ChatCodeDraft?> show(BuildContext context) =>
      showDialog<ChatCodeDraft>(
        context: context,
        builder: (_) => const SendCodeDialog(),
      );

  @override
  State<SendCodeDialog> createState() => _SendCodeDialogState();
}

class _SendCodeDialogState extends State<SendCodeDialog> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  String _language = SendCodeMessage.plainText;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  void _send() {
    if (_code.text.trim().isEmpty) return;
    Navigator.of(
      context,
    ).pop((code: _code.text, language: _language, name: _name.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final t = context.typography;
    final l = AppL10n.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _send,
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _send,
      },
      child: AppDialogFrame(
        title: l.chatSendCode,
        leadingIcon: LucideIcons.codeXml300,
        maxWidth: context.sizes.dialogLg,
        actions: [
          const Spacer(),
          AppButton.textNeutral(
            size: AppButtonSize.small,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.chatCancel),
          ),
          ValueListenableBuilder(
            valueListenable: _code,
            builder: (context, value, _) => AppButton.filled(
              size: AppButtonSize.small,
              onPressed: value.text.trim().isEmpty ? null : _send,
              child: Text(l.chatSend),
            ),
          ),
        ],
        child: Padding(
          padding: EdgeInsets.fromLTRB(s.xl3, 0, s.xl3, s.xl3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _name,
                      style: t.body.copyWith(color: c.textPrimary),
                      decoration: appInputDecoration(
                        context,
                        hint: l.chatCodeName,
                      ),
                    ),
                  ),
                  SizedBox(width: s.lg),
                  Expanded(
                    flex: 2,
                    child: SearchableDropdownField<String>(
                      items: SendCodeMessage.languages,
                      value: _language,
                      hintText: l.chatCodeLanguage,
                      searchHint: l.chatCodeSearchLanguages,
                      emptyLabel: l.chatCodeNoLanguages,
                      labelOf: (language) => language,
                      onChanged: (language) =>
                          setState(() => _language = language),
                    ),
                  ),
                ],
              ),
              SizedBox(height: s.lg),
              TextField(
                controller: _code,
                autofocus: true,
                minLines: 12,
                maxLines: 18,
                maxLength: SendCodeMessage.maxLength,
                keyboardType: TextInputType.multiline,
                style: t.mono.copyWith(
                  fontSize: t.body.fontSize,
                  color: c.textPrimary,
                ),
                decoration:
                    appInputDecoration(
                      context,
                      hint: l.chatCodeHint(SendCodeMessage.maxLength),
                    ).copyWith(
                      counterStyle: t.caption.copyWith(color: c.textTertiary),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
