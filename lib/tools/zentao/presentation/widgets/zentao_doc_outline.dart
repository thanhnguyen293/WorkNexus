import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_context_menu.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_popup_card.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';
import '../util/zentao_doc_prepare.dart';
import 'zentao_doc_reader_controller.dart';

/// "On this page": the document's headings beside it, nested by level along
/// a rail, the one being read lit on the rail. A tap scrolls to a heading.
class ZenTaoDocOutline extends StatelessWidget {
  const ZenTaoDocOutline({
    super.key,
    required this.headings,
    required this.reader,
    this.onPicked,
  });

  final List<ZenTaoDocHeading> headings;
  final ZenTaoDocReader reader;

  /// Called after a heading is picked (the popover closes on it).
  final VoidCallback? onPicked;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final s = context.spacing;
    final top = headings.map((h) => h.level).reduce((a, b) => a < b ? a : b);
    // No scrollbar of its own: beside the page it would run next to the
    // page's, along the same edge.
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView(
        primary: false,
        padding: EdgeInsets.fromLTRB(s.md, s.xl, s.xl, s.xl),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(s.xl, 0, 0, s.md),
            child: Text(
              l.docsOutline,
              style: context.typography.captionStrong.copyWith(
                color: c.textTertiary,
              ),
            ),
          ),
          ValueListenableBuilder<int>(
            valueListenable: reader.activeHeading,
            builder: (context, active, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final h in headings)
                  _Entry(
                    heading: h,
                    depth: h.level - top,
                    active: h.index == active,
                    onTap: () {
                      reader.goToHeading(h.index, gap: s.xl5);
                      onPicked?.call();
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.heading,
    required this.depth,
    required this.active,
    required this.onTap,
  });

  final ZenTaoDocHeading heading;
  final int depth;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final b = context.borders;
    // Hover lights the line and its stretch of the rail, the way the lit
    // entry is drawn, so the pointer reads as "go here".
    return HoverRegion(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered, _) => InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: onTap,
        child: Container(
          // The rail: a hairline down the list, the reader's place on it lit.
          decoration: BoxDecoration(
            border: Border(
              left: active
                  ? BorderSide(color: c.accent, width: b.thick)
                  : BorderSide(
                      color: hovered ? c.textTertiary : c.border,
                      width: b.hairline,
                    ),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            s.xl + s.xl3 * depth - (active ? b.thick - b.hairline : 0),
            s.sm,
            0,
            s.sm,
          ),
          child: Text(
            heading.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.typography.bodySm.copyWith(
              color: active || hovered ? c.textPrimary : c.textSecondary,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// The outline in a popover, for a window too narrow to keep it beside the
/// page.
class ZenTaoDocOutlineButton extends StatelessWidget {
  const ZenTaoDocOutlineButton({
    super.key,
    required this.headings,
    required this.reader,
  });

  final List<ZenTaoDocHeading> headings;
  final ZenTaoDocReader reader;

  @override
  Widget build(BuildContext context) {
    final sizes = context.sizes;
    return MenuAnchor(
      style: appMenuAnchorStyle,
      menuChildren: [
        Builder(
          builder: (context) => Container(
            // Clear of the window's right edge.
            margin: EdgeInsets.only(right: context.spacing.xl),
            width: sizes.toolPaneWidth,
            height: sizes.switcherPopoverHeight,
            child: AppPopupCard(
              child: ZenTaoDocOutline(
                headings: headings,
                reader: reader,
                onPicked: () => MenuController.maybeOf(context)?.close(),
              ),
            ),
          ),
        ),
      ],
      builder: (context, controller, _) => AppIconButton(
        icon: LucideIcons.listTree300,
        tooltip: AppL10n.of(context).docsOutline,
        selected: controller.isOpen,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
