import 'package:flutter/material.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/semantic.dart';

/// The title as it is shared: `#6534 [Discover] Live Stream: …`.
String ticketTitleWithRef(Ticket ticket) =>
    '${ticketShortRef(ticket.providerType, ticket.externalKey)} '
    '${ticket.title}';

/// The detail header's title, led by the ticket's `#id` and selectable, so a
/// drag-select copies it the same way the "Copy title" menu item does.
class DetailHeaderTitle extends StatelessWidget {
  const DetailHeaderTitle({super.key, required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = context.typography.detailTitle;
    return SelectableText.rich(
      TextSpan(
        style: style.copyWith(color: c.textPrimary),
        children: [
          // Quieter than the title: it identifies, the title says what.
          TextSpan(
            text: ticketShortRef(ticket.providerType, ticket.externalKey),
            style: style.copyWith(color: c.textTertiary),
          ),
          TextSpan(text: ' ${ticket.title}'),
        ],
      ),
    );
  }
}
