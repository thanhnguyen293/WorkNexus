import 'package:flutter/material.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_spacing.dart';

/// Widest a document-layout reading column grows to, so long lines stay legible.
const double kDetailDocMaxWidth = 768;

/// Fixed width of the metadata sidebar in the two-pane layout.
const double kDetailMetaPaneWidth = 320;

/// Scrolls a detail tab's body and arranges it per the active [DetailLayout].
///
/// - [DetailLayout.twoPane]: [content] fills the remaining width beside a
///   fixed-width [sidebar] pane (when provided).
/// - [DetailLayout.document]: a centered column capped at [kDetailDocMaxWidth],
///   reading [content] → [sidebar] → [activity].
///
/// [activity] (comments, timeline, composer) closes the main column in
/// two-pane. In document it is split off so the metadata sits right after the
/// narrative instead of being buried beneath an open-ended comment thread.
///
/// Tabs with no metadata pane pass [sidebar] as null; they still get the
/// document layout's centered, capped column.
class DetailScrollBody extends StatelessWidget {
  const DetailScrollBody({
    super.key,
    required this.layout,
    required this.content,
    this.sidebar,
    this.activity,
  });

  final DetailLayout layout;
  final Widget content;
  final Widget? sidebar;
  final Widget? activity;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final sb = sidebar;
    final act = activity;

    final Widget body;
    if (layout == DetailLayout.twoPane) {
      final main = act == null
          ? content
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                SizedBox(height: s.xl3),
                act,
              ],
            );
      body = sb == null
          ? main
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: main),
                SizedBox(width: s.xl3),
                SizedBox(width: kDetailMetaPaneWidth, child: sb),
              ],
            );
    } else {
      body = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kDetailDocMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              content,
              if (sb != null) ...[SizedBox(height: s.xl3), sb],
              if (act != null) ...[SizedBox(height: s.xl3), act],
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(s.xl3, s.xl3, s.xl3, s.xl4),
      child: body,
    );
  }
}
