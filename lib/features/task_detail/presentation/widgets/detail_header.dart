import 'package:flutter/material.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_spacing.dart';
import '../ticket_actions.dart';
import 'detail_header_title.dart';
import 'detail_header_top_bar.dart';
import 'detail_people.dart';
import 'parent_task_link.dart';

/// The detail panel header, read top-down in order of what matters: where
/// the ticket lives (quiet), its title (the largest text), then who holds it
/// beside what to do next. Status and the other facts sit in the sidebar,
/// as in ZenTao.
class DetailHeader extends StatelessWidget {
  const DetailHeader({
    super.key,
    required this.ticket,
    required this.wsColor,
    required this.onClose,
  });
  final Ticket ticket;
  final Color wsColor;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return Container(
      padding: EdgeInsets.fromLTRB(s.xl3, s.xl, s.xl3, s.xl2),
      decoration: BoxDecoration(border: Border(bottom: context.hairlineSide)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailHeaderTopBar(
            ticket: ticket,
            wsColor: wsColor,
            onClose: onClose,
          ),
          SizedBox(height: s.xl),
          // A subtask names its parent right above its own title.
          if (ticket.providerEntity case ZenTaoTaskEntity(
            :final parentId?,
            :final parentName,
          )) ...[
            ParentTaskLink(
              ticket: ticket,
              parentId: parentId,
              parentName: parentName,
            ),
            SizedBox(height: s.md),
          ],
          DetailHeaderTitle(ticket: ticket),
          SizedBox(height: s.xl2),
          // People on the left, actions on the right; they stack when the
          // panel is too narrow for both.
          // Full width, so space-between has room to push them apart.
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: s.xl2,
              runSpacing: s.lg,
              children: [
                DetailPeople(ticket: ticket),
                TicketActionsBar(ticket: ticket),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
