import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/value_objects/translation_state.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/fonts.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/translation_language_control.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../translation/presentation/translation_providers.dart';

/// Sticky footer under the translation tab — the Translate / Retry action.
class TranslationFooter extends ConsumerWidget {
  const TranslationFooter({super.key, required this.ticketId});
  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final state = ref.watch(translationStatusProvider(ticketId)).state;
    final loading = state == TranslationState.loading;
    final targetLang = ref.watch(
      appSettingsProvider.select((s) => s.translationLang),
    );

    final (AppButtonVariant variant, String label) = switch (state) {
      TranslationState.loading => (AppButtonVariant.filled, l.translating),
      TranslationState.error => (AppButtonVariant.error, l.retry),
      TranslationState.none => (AppButtonVariant.filled, l.translate),
      _ => (AppButtonVariant.filledNeutral, l.retranslate),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.xl2,
        vertical: context.spacing.xl,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: context.hairlineSide),
      ),
      child: Row(
        children: [
          AppButton(
            style: variant.style(context),
            isLoading: loading,
            onPressed: loading
                ? null
                : () => translateWithOpenCode(context, ref, ticketId),
            child: Text(label),
          ),
          // A run can outlast the user's patience (a queued model, a wedged
          // CLI), so give them a way out instead of only the hard timeout.
          if (loading) ...[
            SizedBox(width: context.spacing.md),
            AppButton.textNeutral(
              onPressed: () => ref
                  .read(translationControllerProvider.notifier)
                  .cancel(ticketId),
              child: Text(l.cancel),
            ),
          ],
          SizedBox(width: context.spacing.lg),
          Expanded(
            child: Text(
              l.machineTranslationNote,
              style: context.typography.captionSm.copyWith(
                color: c.textTertiary,
                height: 1.4,
              ),
            ),
          ),
          SizedBox(width: context.spacing.lg),
          TranslationLanguageControl(
            value: targetLang,
            tooltip: l.translationLanguage,
            onChanged: ref
                .read(appSettingsProvider.notifier)
                .setTranslationLang,
          ),
        ],
      ),
    );
  }
}

/// Runs a translation through OpenCode. If OpenCode has no authenticated
/// provider yet, points at Settings → OpenCode (or `opencode auth login`) rather
/// than failing with a raw CLI error.
Future<void> translateWithOpenCode(
  BuildContext context,
  WidgetRef ref,
  String ticketId,
) async {
  final authed = await ref.read(openCodeAuthedProvider.future);
  if (!authed) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => const _OpenCodeNotLinkedDialog(),
    );
    return;
  }
  await ref
      .read(translationControllerProvider.notifier)
      .translate(ticketId, force: true);
}

/// Explains how to link OpenCode when no provider is authenticated: paste a key
/// in Settings, or run the CLI login for an OAuth provider.
class _OpenCodeNotLinkedDialog extends ConsumerWidget {
  const _OpenCodeNotLinkedDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.lg),
      ),
      title: Row(
        children: [
          Text('🔗', style: context.typography.title),
          SizedBox(width: context.spacing.md),
          Text(
            l.openCodeNotLinkedTitle,
            style: context.typography.title.copyWith(color: c.textPrimary),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.openCodeNotLinkedBody,
              style: context.typography.paragraph.copyWith(
                color: c.textSecondary,
              ),
            ),
            SizedBox(height: context.spacing.xl),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: context.spacing.xl,
                vertical: context.spacing.lg,
              ),
              decoration: BoxDecoration(
                color: c.surfaceSubtle,
                borderRadius: BorderRadius.circular(context.radii.md),
                border: Border.all(color: c.border),
              ),
              child: SelectableText(
                'opencode auth login',
                style: context.typography.body.copyWith(
                  fontFamily: kMonoFont,
                  color: c.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        AppButton.textNeutral(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.gotIt),
        ),
        SizedBox(width: context.spacing.md),
        AppButton.filled(
          onPressed: () {
            Navigator.of(context).pop();
            ref.read(openTicketIdProvider.notifier).close();
            ref.read(settingsOpenProvider.notifier).state = true;
          },
          child: Text(l.openCodeOpenSettings),
        ),
      ],
    );
  }
}
