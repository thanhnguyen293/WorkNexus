import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/translation_language_control.dart';
import '../../../../l10n/app_localizations.dart';

/// Settings section for the language tickets and chat messages are translated
/// into.
class TranslationLanguageCard extends ConsumerWidget {
  const TranslationLanguageCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final lang = ref.watch(
      appSettingsProvider.select((s) => s.translationLang),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.translationLanguageSection,
          style: context.typography.titleLg.copyWith(color: c.textPrimary),
        ),
        SizedBox(height: context.spacing.xs),
        Text(
          l.translationLanguageSubtitle,
          style: context.typography.paragraph.copyWith(color: c.textSecondary),
        ),
        SizedBox(height: context.spacing.xl2),
        Container(
          padding: EdgeInsets.all(context.spacing.xl2),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(context.radii.md),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.translationLanguage,
                  style: context.typography.body.copyWith(color: c.textPrimary),
                ),
              ),
              TranslationLanguageControl(
                value: lang,
                tooltip: l.translationLanguage,
                onChanged: ref
                    .read(appSettingsProvider.notifier)
                    .setTranslationLang,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
