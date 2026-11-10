import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/zentao_doc.dart';
import '../providers/zentao_doc_providers.dart';
import '../util/zentao_doc_prepare.dart';
import 'zentao_doc_find_bar.dart';
import 'zentao_doc_header.dart';
import 'zentao_doc_history_button.dart';
import 'zentao_doc_outline.dart';
import 'zentao_doc_page.dart';
import 'zentao_doc_reader_controller.dart';
import 'zentao_doc_reader_theme.dart';

/// One document: its cached copy at once, fetched afresh when opened. A text
/// document shows its HTML body; an attachment document its files. Find in
/// the document (⌘F / Ctrl+F) and its outline — beside the page when there
/// is room, in a popover otherwise — work on the body as prepared here.
class ZenTaoDocViewer extends ConsumerStatefulWidget {
  const ZenTaoDocViewer({
    super.key,
    required this.account,
    required this.docId,
  });

  final Account account;
  final String docId;

  @override
  ConsumerState<ZenTaoDocViewer> createState() => _ZenTaoDocViewerState();
}

class _ZenTaoDocViewerState extends ConsumerState<ZenTaoDocViewer> {
  final _reader = ZenTaoDocReader();
  bool _finding = false;
  String _query = '';

  ZenTaoDocPrepared? _prepared;
  String? _preparedHtml;
  String? _preparedQuery;

  @override
  void dispose() {
    _reader.dispose();
    super.dispose();
  }

  /// The body with its outline anchors and find marks — prepared again only
  /// when the body or the query changes.
  ZenTaoDocPrepared _prepare(String html) {
    final cached = _prepared;
    if (cached != null && _preparedHtml == html && _preparedQuery == _query) {
      return cached;
    }
    final prepared = prepareZenTaoDocHtml(html, query: _query);
    _prepared = prepared;
    _preparedHtml = html;
    _preparedQuery = _query;
    // The marks exist once the page is built from it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reader.resetMatches(prepared.matchCount);
      _reader.revealCurrent();
    });
    return prepared;
  }

  void _openFind() => setState(() => _finding = true);

  void _closeFind() => setState(() {
    _finding = false;
    _query = '';
  });

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final account = widget.account;
    final syncKey = (account: account, libId: null, docId: widget.docId);
    final sync = ref.watch(zentaoDocSyncProvider(syncKey));
    final cached = ref.watch(
      zentaoDocProvider((accountId: account.id, docId: widget.docId)),
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

    final prepared = _prepare(doc.html);
    // Read outside the reader's own theme: the switch returns to it.
    final appBrightness = Theme.of(context).brightness;
    const find = SingleActivator(LogicalKeyboardKey.keyF, meta: true);
    const findCtrl = SingleActivator(LogicalKeyboardKey.keyF, control: true);
    return ZenTaoDocReaderTheme(
      child: CallbackShortcuts(
        bindings: {find: _openFind, findCtrl: _openFind},
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, box) {
              final sizes = context.sizes;
              final outlineWidth = sizes.toolPaneCompactWidth;
              final hasOutline = prepared.headings.length >= 2;
              // Beside the page only with room for both.
              final outlineBeside =
                  hasOutline &&
                  box.maxWidth >=
                      sizes.readingWidth +
                          outlineWidth +
                          context.spacing.xl6 * 2;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The page spans the whole width, so its scrollbar runs
                  // down the window's right edge; the outline sits over the
                  // page's right margin, which the page leaves free for it.
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ZenTaoDocPage(
                            account: account,
                            doc: doc,
                            html: prepared.html,
                            reader: _reader,
                            rightInset: outlineBeside ? outlineWidth : 0,
                          ),
                        ),
                        if (outlineBeside)
                          Positioned(
                            // Below the floating tools.
                            top: context.sizes.controlLg + context.spacing.xl,
                            // Clear of the page's scrollbar along the edge.
                            right: context.spacing.lg,
                            bottom: 0,
                            width: outlineWidth,
                            child: ZenTaoDocOutline(
                              headings: prepared.headings,
                              reader: _reader,
                            ),
                          ),
                        Positioned(
                          top: context.spacing.md,
                          right: context.spacing.lg + context.spacing.md,
                          // The find bar floats on the tools' line, to their
                          // left.
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_finding) ...[
                                ZenTaoDocFindBar(
                                  reader: _reader,
                                  query: _query,
                                  onQuery: (q) => setState(() => _query = q),
                                  onClose: _closeFind,
                                ),
                                SizedBox(width: context.spacing.sm),
                              ],
                              ZenTaoDocToolbar(
                                doc: doc,
                                appBrightness: appBrightness,
                                syncing: sync.isLoading,
                                onRefresh: refresh,
                                finding: _finding,
                                history: ZenTaoDocHistoryButton(
                                  account: account,
                                  docId: widget.docId,
                                ),
                                onFind: _finding ? _closeFind : _openFind,
                                webUrl: _webUrl(account, doc),
                                outline: hasOutline && !outlineBeside
                                    ? ZenTaoDocOutlineButton(
                                        headings: prepared.headings,
                                        reader: _reader,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// The document on ZenTao's web (`doc-view-{id}.html`).
  static Uri? _webUrl(Account account, ZenTaoDoc doc) {
    final base = account.baseUrl;
    if (base == null || base.isEmpty) return null;
    return Uri.tryParse('$base/')?.resolve('doc-view-${doc.id}.html');
  }
}
