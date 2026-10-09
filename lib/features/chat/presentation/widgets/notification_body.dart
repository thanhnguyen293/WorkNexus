import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/find_linked_ticket.dart';
import '../../domain/value_objects/message_content.dart';
import 'chat_bubble_theme.dart';
import 'chat_links.dart';
import 'message_body.dart';
import 'zentao_ticket_card.dart';

/// A ZenTao / xuanbot notification: who it is from and the project on one
/// line, the title, then the item — as a live ticket card (status,
/// priority, assignee) when it is a ZenTao bug / task / story, else its
/// Markdown text — and "View details" (a ZenTao item opens beside the chat)
/// with its other actions.
class NotificationBody extends ConsumerWidget {
  const NotificationBody({
    super.key,
    required this.accountId,
    required this.notification,
  });

  final String accountId;
  final NotificationContent notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ink = ChatBubbleTheme.of(context);
    final s = context.spacing;
    final l = AppL10n.of(context);
    final n = notification;
    final subtitle = n.subtitle != n.title ? n.subtitle : null;
    final url = n.url;
    // The card already says what the text would (and keeps it current).
    final ticketUrl = url != null && FindLinkedTicket.parse(url) != null
        ? url
        : null;
    final meta = [?n.sender, ?subtitle].join(' · ');
    final links = [
      if (n.url case final url?) (label: l.chatViewDetail, url: url),
      for (final a in n.actions)
        if (a.url != n.url) (label: a.label, url: a.url),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (meta.isNotEmpty)
          Text(
            meta,
            style: context.typography.caption.copyWith(color: ink.meta),
          ),
        if (n.title case final title?)
          Padding(
            padding: EdgeInsets.only(top: meta.isEmpty ? 0 : s.xxs),
            child: Text(
              title,
              style: context.typography.bodyStrong.copyWith(
                color: ink.text,
                fontSize: ink.fontSize,
              ),
            ),
          ),
        if (ticketUrl != null)
          Padding(
            padding: EdgeInsets.only(top: s.md),
            child: ZenTaoTicketCard(
              url: ticketUrl,
              // The card heads with "Bug #id" already.
              fallbackTitle: n.text.isEmpty
                  ? null
                  : n.text.replaceFirst(RegExp(r'^#\d+\s*'), ''),
            ),
          )
        else if (n.text.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: n.title == null ? 0 : s.sm),
            child: ChatTextBody(
              accountId: accountId,
              text: n.text,
              markdown: n.markdown,
            ),
          ),
        if (links.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: s.md),
            child: Wrap(
              spacing: s.md,
              runSpacing: s.sm,
              children: [
                for (final (i, link) in links.indexed)
                  TextButton.icon(
                    onPressed: () => openChatLink(ref, link.url),
                    style: TextButton.styleFrom(
                      foregroundColor: ink.link,
                      padding: EdgeInsets.symmetric(horizontal: s.md),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: Icon(
                      i == 0 && n.url != null
                          ? PhosphorIconsLight.arrowCircleRight
                          : PhosphorIconsLight.arrowSquareOut,
                      size: s.xl3,
                    ),
                    label: Text(link.label),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
