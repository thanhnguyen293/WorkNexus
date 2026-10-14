import 'package:flutter/material.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import 'detail_region_card.dart';

/// Widest a document-layout reading column grows to, so long lines stay legible.
const double kDetailDocMaxWidth = 768;

/// Fixed width of the metadata sidebar in the two-pane layout.
const double kDetailMetaPaneWidth = 320;

/// Scrolls a detail tab's body and arranges it per the active [DetailLayout],
/// on a tinted ground with [content] and [activity] each in a
/// [DetailRegionCard]. The [sidebar] and [linked] bring their own cards, as
/// they may split into several regions (or show none).
///
/// - [DetailLayout.twoPane]: [content] fills the remaining width beside a
///   fixed-width [sidebar] pane (when provided).
/// - [DetailLayout.document]: a centered column capped at [kDetailDocMaxWidth],
///   reading [content] → [linked] → [sidebar] → [activity].
///
/// [linked] (a task's subtasks, its related bugs) follows [content] in either
/// layout; each of its cards spaces itself from the one above.
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
    this.linked,
    this.sidebar,
    this.activity,
  });

  final DetailLayout layout;
  final Widget content;
  final Widget? linked;
  final Widget? sidebar;
  final Widget? activity;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final sb = sidebar;
    final act = switch (activity) {
      final a? => DetailRegionCard(child: a),
      null => null,
    };
    final content = DetailRegionCard(child: this.content);

    final Widget body;
    if (layout == DetailLayout.twoPane) {
      final main = act == null && linked == null
          ? content
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                ?linked,
                if (act != null) ...[SizedBox(height: s.xl), act],
              ],
            );
      body = sb == null
          ? main
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: main),
                SizedBox(width: s.xl),
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
              ?linked,
              if (sb != null) ...[SizedBox(height: s.xl), sb],
              if (act != null) ...[SizedBox(height: s.xl), act],
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      // The board's canvas grey: dark enough that the white region cards
      // stand off it in light mode (and lighter cards still do in dark).
      color: context.colors.background,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(s.xl2, s.xl2, s.xl2, s.xl4),
        child: body,
      ),
    );
  }
}
