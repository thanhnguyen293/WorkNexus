import 'package:flutter/material.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/markdown_text.dart';
import '../../../../l10n/app_localizations.dart';

/// The rendered item body for the two-pane details (GitLab MR / GitHub PR). Just
/// the description markdown, or a muted placeholder when there's no body — author
/// / branches / dates already live in the header and sidebar.
class ItemDescription extends StatelessWidget {
  const ItemDescription({super.key, required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final body = ticket.body.trim();
    if (body.isEmpty) {
      return Text(
        AppL10n.of(context).noDescription,
        style: context.typography.body.copyWith(
          color: context.colors.textTertiary,
        ),
      );
    }
    return MarkdownText(ticket.body);
  }
}
