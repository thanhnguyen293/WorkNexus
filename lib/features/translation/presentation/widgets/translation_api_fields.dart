import 'package:flutter/material.dart';

import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/connection_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/translation_api_preset.dart';
import 'translation_api_model_field.dart';

/// Endpoint, model and key for an API provider.
class TranslationApiFields extends StatelessWidget {
  const TranslationApiFields({
    super.key,
    required this.preset,
    required this.baseUrl,
    required this.model,
    required this.apiKey,
    required this.obscure,
    required this.onToggleObscure,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TranslationApiPreset preset;
  final TextEditingController baseUrl;
  final TextEditingController model;
  final TextEditingController apiKey;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onChanged;

  /// Enter in a field: saves when the form is complete.
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final keyUrl = preset.keyUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (preset == TranslationApiPreset.custom) ...[
          ConnectionTextField(
            label: l.translationApiBaseUrl,
            controller: baseUrl,
            hint: l.translationApiBaseUrlHint,
            onChanged: (_) => onChanged(),
            onSubmitted: (_) => onSubmitted(),
          ),
          SizedBox(height: context.spacing.lg),
        ],
        if (preset.needsKey) ...[
          ConnectionTextField(
            label: l.translationApiKey,
            controller: apiKey,
            obscure: obscure,
            onChanged: (_) => onChanged(),
            onSubmitted: (_) => onSubmitted(),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (keyUrl != null)
                  AppButton.text(
                    size: AppButtonSize.small,
                    onPressed: () => openExternally(keyUrl),
                    child: Text(l.translationApiGetKey),
                  ),
                AppButton.text(
                  size: AppButtonSize.small,
                  onPressed: onToggleObscure,
                  child: Text(obscure ? l.openCodeShowKey : l.openCodeHideKey),
                ),
              ],
            ),
          ),
          SizedBox(height: context.spacing.lg),
        ],
        TranslationApiModelField(
          baseUrl: baseUrl.text,
          apiKey: apiKey.text,
          needsKey: preset.needsKey,
          controller: model,
          onChanged: (_) => onChanged(),
          onSubmitted: (_) => onSubmitted(),
        ),
      ],
    );
  }
}
