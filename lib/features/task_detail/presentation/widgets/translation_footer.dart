import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/value_objects/translation_state.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/fonts.dart';
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

    String label;
    Color bg;
    Color fg = c.onAccent;
    if (loading) {
      label = l.translating;
      bg = c.accent;
    } else if (state == TranslationState.error) {
      label = 'Retry';
      bg = c.error;
    } else if (state == TranslationState.none) {
      label = l.translate;
      bg = c.accent;
    } else {
      label = l.retranslate;
      bg = c.surfaceSubtle;
      fg = c.textPrimary;
    }

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
          FilledButton(
            onPressed: loading
                ? null
                : () => translateWithOpenCode(context, ref, ticketId),
            style: FilledButton.styleFrom(
              backgroundColor: bg,
              foregroundColor: fg,
              disabledBackgroundColor: c.accent.withValues(alpha: 0.6),
              padding: EdgeInsets.symmetric(
                horizontal: context.spacing.xl2,
                vertical: context.spacing.xl,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading) ...[
                  SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.onAccent,
                    ),
                  ),
                  SizedBox(width: context.spacing.md),
                ],
                Text(label),
              ],
            ),
          ),
          SizedBox(width: context.spacing.lg),
          Expanded(
            child: Text(
              'Machine translation · review before relying on it',
              style: context.typography.captionSm.copyWith(
                color: c.textTertiary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Runs a translation through OpenCode. If OpenCode isn't authenticated yet,
/// shows guidance to run `opencode auth login` (we intentionally don't manage a
/// provider key ourselves — that would bypass OpenCode's own usage tracking).
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

/// Explains how to link OpenCode when no provider is authenticated.
class _OpenCodeNotLinkedDialog extends StatelessWidget {
  const _OpenCodeNotLinkedDialog();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
            'OpenCode not linked',
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
              'No authenticated OpenCode provider was found. Link one from your '
              'terminal so translations run through your account and appear in '
              'OpenCode usage:',
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
            SizedBox(height: context.spacing.lg),
            Text(
              'Then retry Translate.',
              style: context.typography.meta.copyWith(color: c.textTertiary),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            backgroundColor: c.accent,
            foregroundColor: c.onAccent,
          ),
          child: const Text('Got it'),
        ),
      ],
    );
  }
}
