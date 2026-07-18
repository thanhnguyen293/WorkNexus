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
///   with [sidebar] (if any) stacked below [content].
///
/// Tabs with no metadata pane pass [sidebar] as null; they still get the
/// document layout's centered, capped column.
class DetailScrollBody extends StatelessWidget {
  const DetailScrollBody({
    super.key,
    required this.layout,
    required this.content,
    this.sidebar,
  });

  final DetailLayout layout;
  final Widget content;
  final Widget? sidebar;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final sb = sidebar;

    final Widget body;
    if (layout == DetailLayout.twoPane) {
      body = sb == null
          ? content
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: content),
                SizedBox(width: s.xl3),
                SizedBox(width: kDetailMetaPaneWidth, child: sb),
              ],
            );
    } else {
      body = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kDetailDocMaxWidth),
          child: sb == null
              ? content
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    content,
                    SizedBox(height: s.xl3),
                    sb,
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
