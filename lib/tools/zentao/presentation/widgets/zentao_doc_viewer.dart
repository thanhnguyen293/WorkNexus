import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/zentao_doc_providers.dart';
import 'zentao_doc_body.dart';
import 'zentao_doc_files.dart';
import 'zentao_doc_header.dart';
import 'zentao_doc_reader_theme.dart';

/// One document: its cached copy at once, fetched afresh when opened. A text
/// document shows its HTML body; an attachment document its files.
class ZenTaoDocViewer extends ConsumerWidget {
  const ZenTaoDocViewer({
    super.key,
    required this.account,
    required this.docId,
  });

  final Account account;
  final String docId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final syncKey = (account: account, libId: null, docId: docId);
    final sync = ref.watch(zentaoDocSyncProvider(syncKey));
    final cached = ref.watch(
      zentaoDocProvider((accountId: account.id, docId: docId)),
    );
    final doc = cached.asData?.value;
    void refresh() =>
        ref.read(zentaoDocSyncProvider(syncKey).notifier).refresh();

    // Every state sits on the reader's page, so switching documents never
    // shows the window's (greyer) background between two pages.
    if (doc == null) {
      final Widget state;
      if (!cached.hasValue) {
        // The cache answers within a frame: a spinner here would only blink.
        state = const SizedBox.expand();
      } else if (sync.isLoading) {
        state = const AppStateView.loading();
      } else {
        final failure = switch (sync.error) {
          ZenTaoDocSyncException(:final failure) => failure,
          _ => null,
        };
        state = failure is NotFoundFailure
            ? AppStateView.error(
                title: l.docsUnreadable,
                message: l.docsUnreadableHint,
                icon: LucideIcons.fileLock300,
                onRetry: refresh,
              )
            : AppStateView.error(onRetry: refresh);
      }
      return ZenTaoDocReaderTheme(child: state);
    }

    final s = context.spacing;
    final reading = context.sizes.readingWidth;
    // Read outside the reader's own theme: the switch returns to it.
    final appBrightness = Theme.of(context).brightness;
    return ZenTaoDocReaderTheme(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ZenTaoDocToolbar(
            doc: doc,
            appBrightness: appBrightness,
            syncing: sync.isLoading,
            onRefresh: refresh,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                // The column is centred by padding, not by a narrower box, so
                // the wheel scrolls the page wherever the pointer is.
                final side = math.max(s.xl6, (box.maxWidth - reading) / 2);
                Widget pad(
                  Widget sliver, {
                  double top = 0,
                  double bottom = 0,
                }) => SliverPadding(
                  padding: EdgeInsets.fromLTRB(side, top, side, bottom),
                  sliver: sliver,
                );
                // One selection across title, text, tables and code, so any
                // part of the page can be dragged over and copied.
                return SelectionArea(
                  child: CustomScrollView(
                    // Keeps the reading position across a trip elsewhere.
                    key: PageStorageKey('zentao-doc-$docId'),
                    slivers: [
                      pad(
                        SliverToBoxAdapter(
                          child: ZenTaoDocHeader(
                            accountId: account.id,
                            doc: doc,
                          ),
                        ),
                        top: s.md,
                        bottom: s.xl5,
                      ),
                      if (doc.hasBody)
                        pad(
                          ZenTaoDocBody(
                            doc.html,
                            imageLoader: (url) => ref
                                .read(zenTaoDocRepositoryProvider)
                                .fetchImage(account, url),
                            imageFallbackUrl: (url) =>
                                _absolute(account.baseUrl, url),
                          ),
                        )
                      else if (doc.isAttachment && doc.files.isEmpty)
                        pad(
                          SliverToBoxAdapter(
                            child: Text(
                              l.docsAttachmentOnly,
                              style: context.typography.body.copyWith(
                                color: context.colors.textTertiary,
                              ),
                            ),
                          ),
                        ),
                      if (doc.files.isNotEmpty)
                        pad(
                          SliverToBoxAdapter(
                            child: ZenTaoDocFiles(
                              account: account,
                              files: doc.files,
                              // An attachment document reads as its file.
                              openFirst: doc.isAttachment && !doc.hasBody,
                            ),
                          ),
                          top: s.xl5,
                        ),
                      pad(const SliverToBoxAdapter(), bottom: s.xl6),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String? _absolute(String? baseUrl, String url) {
    if (baseUrl == null || baseUrl.isEmpty) return null;
    return Uri.parse('$baseUrl/').resolve(url).toString();
  }
}
