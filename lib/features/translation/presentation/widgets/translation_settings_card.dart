import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/translation_languages.dart';
import '../../../../core/widgets/translation_language_control.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/translation_api_preset.dart';
import '../translation_api_providers.dart';
import 'translation_api_form.dart';
import 'translation_model_picker.dart';

/// One collapsible settings card for everything translation: the target
/// language, the OpenCode model and the optional own-API-key backend. Collapsed
/// it states what is in force (`Tiếng Việt · Google Gemini`).
class TranslationSettingsCard extends ConsumerStatefulWidget {
  const TranslationSettingsCard({super.key});

  @override
  ConsumerState<TranslationSettingsCard> createState() =>
      _TranslationSettingsCardState();
}

class _TranslationSettingsCardState
    extends ConsumerState<TranslationSettingsCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lang = ref.watch(
      appSettingsProvider.select((s) => s.translationLang),
    );
    final saved = ref.watch(translationApiConfigProvider).asData?.value;
    final api = saved?.valueOrNull;
    final backend = api != null && api.isUsable
        ? _presetName(context, TranslationApiPreset.byId(api.presetId))
        : 'OpenCode';
    final summary = '${translationLanguageFor(lang).nativeName} · $backend';

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(context.radii.md),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            summary: summary,
            expanded: _expanded,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? _Body(lang: lang)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

String _presetName(BuildContext context, TranslationApiPreset preset) =>
    preset == TranslationApiPreset.custom
    ? AppL10n.of(context).translationApiCustom
    : preset.name;

class _Header extends StatelessWidget {
  const _Header({
    required this.summary,
    required this.expanded,
    required this.onTap,
  });

  final String summary;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(context.spacing.xl2),
        child: Row(
          children: [
            Icon(PhosphorIconsLight.translate, size: 20, color: c.accent),
            SizedBox(width: context.spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.translationSection,
                    style: context.typography.titleLg.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                  SizedBox(height: context.spacing.xs),
                  Text(
                    summary,
                    style: context.typography.paragraph.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 180),
              child: Icon(
                PhosphorIconsLight.caretDown,
                size: 18,
                color: c.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.lang});

  final String lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: l.translationLanguageSection,
          hint: l.translationLanguageSubtitle,
          trailing: TranslationLanguageControl(
            value: lang,
            tooltip: l.translationLanguage,
            onChanged: ref
                .read(appSettingsProvider.notifier)
                .setTranslationLang,
          ),
        ),
        _Section(
          title: l.translationModelSection,
          hint: l.translationModelSubtitle,
          child: const TranslationModelPicker(),
        ),
        _Section(
          title: l.translationApiSection,
          hint: l.translationApiSubtitle,
          child: const TranslationApiForm(),
        ),
      ],
    );
  }
}

/// A titled block inside the card: [trailing] sits beside the title (a short
/// control), [child] below it (a form).
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.hint,
    this.trailing,
    this.child,
  });

  final String title;
  final String hint;
  final Widget? trailing;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.spacing.xl2),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: context.typography.body.copyWith(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          SizedBox(height: context.spacing.xs),
          Text(
            hint,
            style: context.typography.caption.copyWith(color: c.textTertiary),
          ),
          if (child != null) ...[SizedBox(height: context.spacing.lg), child!],
        ],
      ),
    );
  }
}
