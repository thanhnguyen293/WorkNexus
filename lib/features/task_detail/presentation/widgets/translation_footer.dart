import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/value_objects/translation_state.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/translation/translation_providers.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/opencode_not_linked_dialog.dart';
import '../../../../core/widgets/translation_language_control.dart';
import '../../../../l10n/app_localizations.dart';

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

/// Runs a translation through OpenCode, first making sure it is linked.
Future<void> translateWithOpenCode(
  BuildContext context,
  WidgetRef ref,
  String ticketId,
) async {
  if (!await ensureOpenCodeLinked(context, ref)) return;
  await ref
      .read(translationControllerProvider.notifier)
      .translate(ticketId, force: true);
}
