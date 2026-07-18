import 'package:flutter/material.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/settings/app_settings.dart';
import '../detail_providers.dart';
import 'comments_tab.dart';
import 'development_tab.dart';
import 'original_tab.dart';
import 'translation_tab.dart';

/// Renders the active detail tab's content in the chosen [layout].
class DetailTabBody extends StatelessWidget {
  const DetailTabBody({
    super.key,
    required this.ticket,
    required this.tab,
    required this.layout,
  });
  final Ticket ticket;
  final DetailTab tab;
  final DetailLayout layout;

  @override
  Widget build(BuildContext context) {
    switch (tab) {
      case DetailTab.original:
        return OriginalTab(ticket: ticket, layout: layout);
      case DetailTab.translation:
        return TranslationTab(ticket: ticket, layout: layout);
      case DetailTab.comments:
        return CommentsTab(ticketId: ticket.id, layout: layout);
      case DetailTab.development:
        return DevelopmentTab(ticket: ticket, layout: layout);
    }
  }
}
