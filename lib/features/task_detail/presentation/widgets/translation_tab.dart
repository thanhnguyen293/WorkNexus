import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/translation_state.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/translation_languages.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../core/widgets/markdown_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../sync/data/sync_service.dart';
import '../../../translation/presentation/translation_providers.dart';
import '../util/image_fallback.dart';
import 'detail_scroll_body.dart';
import 'section_label.dart';

/// The "Vietnamese" tab — shows the translation record and its lifecycle state.
class TranslationTab extends ConsumerWidget {
  const TranslationTab({super.key, required this.ticket, required this.layout});
  final Ticket ticket;
  final DetailLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final status = ref.watch(translationStatusProvider(ticket.id));
    final state = status.state;
    final record = status.record;
    // The translated body carries the original's inline-image links, so give it
    // the same "open in browser" fallback (e.g. GitLab < 17.4 uploads).
    final imageFallback = ImageFallback.forTicket(
      ticket,
      ref.watch(lookupsProvider).accounts[ticket.accountId],
    );
    final lang = translationLanguageFor(
      ref.watch(appSettingsProvider.select((s) => s.translationLang)),
    );

    Widget banner(Color hue, String text) => Container(
      margin: EdgeInsets.only(bottom: context.spacing.xl2),
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.xl,
        vertical: context.spacing.lg,
      ),
      decoration: BoxDecoration(
        color: c.mixT(hue, 0.11),
        borderRadius: BorderRadius.circular(context.radii.md),
        border: Border.all(color: c.mixT(hue, 0.38)),
      ),
      child: Text(
        text,
        style: context.typography.paragraphSm.copyWith(color: c.textPrimary),
      ),
    );

    return DetailScrollBody(
      layout: layout,
      content: Column(
        crossAxisAlignment: state == TranslationState.none
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          if (state == TranslationState.none)
            Column(
              children: [
                SizedBox(height: context.spacing.xl4),
                Text(lang.flag, style: context.typography.displayLg),
                SizedBox(height: context.spacing.lg),
                Text(
                  l.notTranslated,
                  style: context.typography.subtitle.copyWith(
                    color: c.textPrimary,
                  ),
                ),
                SizedBox(height: context.spacing.sm),
                Text(
                  l.runOpenCodeToTranslate(lang.nativeName),
                  textAlign: TextAlign.center,
                  style: context.typography.paragraphSm.copyWith(
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          if (state == TranslationState.loading) ...[
            Row(
              children: [
                SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.accent,
                  ),
                ),
                SizedBox(width: context.spacing.lg),
                Text(
                  l.translating,
                  style: context.typography.secondary.copyWith(
                    fontWeight: FontWeight.w500,
                    color: c.textPrimary,
                  ),
                ),
              ],
            ),
            SizedBox(height: context.spacing.xl3),
            const SkeletonBox(width: 200, height: 13),
            SizedBox(height: context.spacing.lg),
            const SkeletonBox(width: double.infinity, height: 11),
            SizedBox(height: context.spacing.md),
            const SkeletonBox(width: double.infinity, height: 11),
          ],
          if (state == TranslationState.outdated)
            banner(
              c.warning,
              'Original changed since last translation. Showing the earlier version.',
            ),
          if (state == TranslationState.error)
            banner(
              c.error,
              'Translation failed — OpenCode timed out. Retry to run it again.',
            ),
          if ((state == TranslationState.done ||
                  state == TranslationState.outdated) &&
              record != null) ...[
            Opacity(
              opacity: state == TranslationState.outdated ? 0.62 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.translatedTitle,
                    style: context.typography.title.copyWith(
                      color: c.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: context.spacing.xl),
                  SectionLabel(l.description),
                  SizedBox(height: context.spacing.md),
                  MarkdownText(
                    record.translatedBody,
                    imageLoader: (url) =>
                        getIt<SyncService>().fetchTicketImage(ticket, url),
                    imageFallbackUrl: imageFallback.resolveUrl,
                    onOpenImage: imageFallback.open,
                  ),
                ],
              ),
            ),
            if (state == TranslationState.done) ...[
              SizedBox(height: context.spacing.xl2),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: c.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: context.spacing.sm),
                  Text(
                    '${l.translated} · via OpenCode',
                    style: context.typography.caption.copyWith(
                      color: c.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
