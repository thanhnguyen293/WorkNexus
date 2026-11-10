import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/platform/open_external.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/relative_time.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/board/presentation/widgets/board_refresh_button.dart';
import '../../domain/entities/zentao_doc.dart';
import '../../domain/usecases/render_zentao_doc_markdown.dart';
import '../providers/zentao_doc_providers.dart';
import 'zentao_doc_people.dart';

/// The reader's tools, floating at the page's top right: find in the
/// document, the outline (when it isn't beside the page), history, export,
/// copy as Markdown, copy its link, open on ZenTao's web, the page's light /
/// dark switch and refresh.
class ZenTaoDocToolbar extends ConsumerWidget {
  const ZenTaoDocToolbar({
    super.key,
    required this.doc,
    required this.appBrightness,
    required this.syncing,
    required this.onRefresh,
    required this.finding,
    required this.onFind,
    required this.history,
    required this.export,
    this.webUrl,
    this.outline,
  });

  final ZenTaoDoc doc;
  final bool finding;

  /// The history button (its popover holds the document's history).
  final Widget history;

  /// The export button (its menu saves the document as Markdown, HTML or a
  /// JSON backup).
  final Widget export;

  /// Opens the find bar, or closes it when [finding].
  final VoidCallback onFind;
  final Uri? webUrl;

  /// The outline's popover button, when the outline isn't beside the page.
  final Widget? outline;

  /// The app's own brightness, which the switch returns to.
  final Brightness appBrightness;
  final bool syncing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final current = Theme.of(context).brightness;
    final dark = current == Brightness.dark;
    final c = context.colors;
    // A floating cluster, not a band across the page: the page scrolls up to
    // its top edge under it rather than being cut off by an empty strip.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(context.radii.md),
        border: Border.all(color: c.border, width: context.borders.hairline),
      ),
      child: Padding(
        padding: EdgeInsets.all(s.xxs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIconButton(
              icon: LucideIcons.search300,
              tooltip: l.docsFind,
              selected: finding,
              onPressed: onFind,
            ),
            ?outline,
            history,
            AppIconButton(
              icon: LucideIcons.copy300,
              tooltip: l.docsCopyMarkdown,
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: zenTaoDocMarkdown(doc)),
                );
                if (context.mounted) showAppSnack(context, l.docsCopied);
              },
            ),
            export,
            if (webUrl case final url?) ...[
              AppIconButton(
                icon: LucideIcons.link300,
                tooltip: l.copyLink,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: url.toString()));
                  if (context.mounted) showAppSnack(context, l.docsLinkCopied);
                },
              ),
              AppIconButton(
                icon: LucideIcons.externalLink300,
                tooltip: l.docsOpenInZenTao,
                onPressed: () => openExternally(url.toString()),
              ),
            ],
            AppIconButton(
              icon: dark ? LucideIcons.sun300 : LucideIcons.moon300,
              tooltip: dark ? l.docsReadOnLight : l.docsReadOnDark,
              onPressed: () => ref
                  .read(zentaoDocReaderBrightnessProvider.notifier)
                  .toggle(current: current, app: appBrightness),
            ),
            BoardRefreshButton(loading: syncing, onPressed: onRefresh),
          ],
        ),
      ),
    );
  }
}

/// The document's title, then who wrote and edited it (faces that open a
/// card to message them), when, and how often it was read — ruled off from
/// the body below, as ZenTao's web sets a document's head apart.
class ZenTaoDocHeader extends ConsumerWidget {
  const ZenTaoDocHeader({
    super.key,
    required this.accountId,
    required this.doc,
  });

  final String accountId;
  final ZenTaoDoc doc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final s = context.spacing;
    final dateFormat = ref.watch(
      appSettingsProvider.select((s) => s.dateFormat),
    );
    String day(DateTime t) => formatDate(context, t, format: dateFormat);
    final metaStyle = context.typography.bodySm.copyWith(color: c.textTertiary);
    final author = doc.author;
    final created = doc.addedDate;
    final edited = doc.editedDate;
    final views = doc.views;

    final people = [
      if (author != null)
        ZenTaoDocPeople(
          accountId: accountId,
          people: [author],
          action: l.docsCreatedAction,
          title: l.docsPeopleCreated,
        ),
      if (doc.editors.isNotEmpty)
        ZenTaoDocPeople(
          accountId: accountId,
          people: doc.editors,
          action: l.docsEditedAction,
          title: l.docsPeopleEdited,
        ),
    ];
    // Short facts, each kept whole: the line breaks between them, never
    // inside one.
    final facts = <Widget>[
      if (doc.version case final v?) Text(l.docsVersion(v), style: metaStyle),
      if (created != null)
        Text(l.docsCreatedOn(day(created)), style: metaStyle),
      if (edited != null && edited != created)
        Text(l.docsEditedOn(day(edited)), style: metaStyle),
      if (views != null)
        Tooltip(
          message: l.docsViews(views),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.eye300,
                size: context.sizes.iconSm,
                color: c.textTertiary,
              ),
              SizedBox(width: s.xs),
              Text('$views', style: metaStyle),
            ],
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          doc.title,
          // The page's title, above the body's own headings (h1 is
          // `display`), as a document title reads on ZenTao's web.
          style: context.typography.displayLg.copyWith(
            height: 1.25,
            color: c.textPrimary,
          ),
        ),
        if (people.isNotEmpty) ...[
          SizedBox(height: s.lg),
          Wrap(spacing: s.md, runSpacing: s.xs, children: people),
        ],
        if (facts.isNotEmpty) ...[
          SizedBox(height: s.sm),
          Wrap(
            spacing: s.md,
            runSpacing: s.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < facts.length; i++) ...[
                if (i > 0) Text('·', style: metaStyle),
                facts[i],
              ],
            ],
          ),
        ],
        SizedBox(height: s.xl4),
        Divider(height: context.borders.hairline, color: c.border),
      ],
    );
  }
}
