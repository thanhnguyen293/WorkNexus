import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/zentao_doc.dart';
import '../providers/zentao_doc_providers.dart';
import 'zentao_doc_body.dart';
import 'zentao_doc_files.dart';
import 'zentao_doc_header.dart';
import 'zentao_doc_reader_controller.dart';

/// The scrolling page of a document: its header, the prepared body ([html]),
/// its files. It tells the [reader] which heading is being read as it
/// scrolls, for the outline.
class ZenTaoDocPage extends ConsumerWidget {
  const ZenTaoDocPage({
    super.key,
    required this.account,
    required this.doc,
    required this.html,
    required this.reader,
    this.rightInset = 0,
  });

  final Account account;
  final ZenTaoDoc doc;
  final String html;
  final ZenTaoDocReader reader;

  /// Width kept free on the right (the outline sits there, over the page).
  final double rightInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final reading = context.sizes.readingWidth;
    return LayoutBuilder(
      builder: (context, box) {
        // The column is centred by padding, not by a narrower box, so the
        // wheel scrolls the page wherever the pointer is.
        final side = math.max(s.xl6, (box.maxWidth - rightInset - reading) / 2);
        Widget pad(Widget sliver, {double top = 0, double bottom = 0}) =>
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                side,
                top,
                side + rightInset,
                bottom,
              ),
              sliver: sliver,
            );
        return NotificationListener<Notification>(
          onNotification: (n) {
            _track(n, lead: s.xl6 * 2);
            return false;
          },
          // One selection across title, text, tables and code, so any part
          // of the page can be dragged over and copied.
          child: SelectionArea(
            child: CustomScrollView(
              // Keeps the reading position across a trip elsewhere.
              key: PageStorageKey('zentao-doc-${doc.id}'),
              slivers: [
                pad(
                  SliverToBoxAdapter(
                    child: ZenTaoDocHeader(accountId: account.id, doc: doc),
                  ),
                  // Room for the floating tools above the title.
                  top: s.xl6 + s.md,
                  bottom: s.xl5,
                ),
                if (doc.hasBody)
                  pad(
                    ZenTaoDocBody(
                      html,
                      reader: reader,
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
          ),
        );
      },
    );
  }

  /// On a scroll or a change of the page's size (its first layout, the body
  /// arriving), works out the heading being read.
  void _track(Notification n, {required double lead}) {
    final (depth, context, metrics) = switch (n) {
      ScrollUpdateNotification(:final depth, :final context, :final metrics) =>
        (depth, context, metrics),
      ScrollMetricsNotification(:final depth, :final context, :final metrics) =>
        (depth, context, metrics),
      _ => (-1, null, null),
    };
    if (depth != 0 || context == null || metrics == null) return;
    if (metrics.axis != Axis.vertical) return;
    final viewport = context.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return;
    reader.trackHeading(
      viewport,
      lead: lead,
      atEnd: metrics.pixels >= metrics.maxScrollExtent - 1,
    );
  }

  static String? _absolute(String? baseUrl, String url) {
    if (baseUrl == null || baseUrl.isEmpty) return null;
    return Uri.parse('$baseUrl/').resolve(url).toString();
  }
}
