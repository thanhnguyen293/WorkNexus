import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/value_objects/ticket_sort.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_context_menu.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/compare_tickets.dart';
import '../providers/board_sort_provider.dart';

/// The toolbar's Sort button: the field the board's cards are ordered by and
/// its direction; a menu of [fields] to pick another, or the same one again
/// to flip the direction.
class BoardSortButton extends ConsumerStatefulWidget {
  const BoardSortButton({super.key, this.fields = boardSortFields});

  final List<TicketSortField> fields;

  @override
  ConsumerState<BoardSortButton> createState() => _BoardSortButtonState();
}

class _BoardSortButtonState extends ConsumerState<BoardSortButton> {
  final _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final sort = ref.watch(boardSortProvider);
    final fields = widget.fields;
    return MenuAnchor(
      controller: _menu,
      style: appMenuAnchorStyle,
      alignmentOffset: Offset(0, context.spacing.xs),
      menuChildren: [
        AppMenuPanel(
          entries: [
            for (final f in fields)
              AppMenuEntry(
                label: boardSortLabel(l, f),
                checked: f == sort.field,
              ),
          ],
          onSelected: (i) {
            _menu.close();
            ref.read(boardSortProvider.notifier).sortBy(fields[i]);
          },
        ),
      ],
      builder: (context, menu, _) => Tooltip(
        message: l.boardSort,
        child: _BoardSortFace(
          sort: sort,
          label: boardSortLabel(l, sort.field),
          onTap: () => menu.isOpen ? menu.close() : menu.open(),
        ),
      ),
    );
  }
}

/// What a sort field is called on the board's Sort button.
String boardSortLabel(AppL10n l, TicketSortField field) => switch (field) {
  TicketSortField.id => l.boardSortCreated,
  TicketSortField.title => l.tableColumnTitle,
  TicketSortField.priority => l.priority,
  TicketSortField.severity => l.severity,
  TicketSortField.status => l.status,
  TicketSortField.assignee => l.assignedTo,
  TicketSortField.estimate => l.estimate,
  TicketSortField.left => l.tableColumnLeft,
  TicketSortField.resolution => l.resolution,
  TicketSortField.updated => l.updated,
};

class _BoardSortFace extends StatelessWidget {
  const _BoardSortFace({
    required this.sort,
    required this.label,
    required this.onTap,
  });

  final TicketSort sort;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final changed = sort != boardDefaultSort;
    final color = changed ? c.accent : c.textSecondary;
    return HoverSurface(
      onTap: onTap,
      height: context.sizes.controlMd,
      padding: EdgeInsets.symmetric(horizontal: s.lg),
      color: changed ? c.selectionFill : c.surface,
      borderRadius: BorderRadius.circular(context.radii.md),
      border: context.cardBorder,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            sort.descending
                ? LucideIcons.arrowDownWideNarrow300
                : LucideIcons.arrowUpNarrowWide300,
            size: context.sizes.iconMd,
            color: color,
          ),
          SizedBox(width: s.sm),
          Text(
            label,
            maxLines: 1,
            style: context.typography.bodySm.copyWith(
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
