import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/util/labels.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/find_linked_ticket.dart';
import '../providers/zentao_link_providers.dart';
import 'chat_link_card_frame.dart';
import 'chat_links.dart';

/// A ZenTao bug / task / story linked in a message, as a compact quote-like
/// card: `Bug #123 · Status`, the title, then `Pri 2 · assignee`. The bar
/// takes the status colour. A ticket the board has not synced is fetched
/// through the connected ZenTao account; a tap opens it beside the chat.
class ZenTaoTicketCard extends ConsumerWidget {
  const ZenTaoTicketCard({super.key, required this.url, this.fallbackTitle});

  final String url;

  /// Shown until the ticket is loaded, or when it cannot be (e.g. a bot
  /// notification already names the item).
  final String? fallbackTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = FindLinkedTicket.parse(url);
    if (link == null) return const SizedBox.shrink();
    final c = context.colors;
    final l = AppL10n.of(context);
    final s = context.spacing;
    final ticket = ref.watch(chatZenTaoTicketProvider(url));
    // Only asked for once the stored tickets are read and none answers the
    // link.
    final storedRead = ref.watch(ticketsProvider.select((t) => t.hasValue));
    final fetch = ticket == null && storedRead
        ? ref.watch(chatZenTaoFetchProvider(url))
        : null;
    final status = ticket == null ? null : statusColor(c, ticket.status);
    final reference =
        '${link.type[0].toUpperCase()}${link.type.substring(1)} #${link.id}';
    final failure = switch (fetch?.value) {
      Err(:final failure) => failure,
      _ => null,
    };
    return ChatLinkCardFrame(
      bar: status,
      onTap: () => openChatLink(ref, url),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const ProviderBadge(ProviderType.zentao),
              SizedBox(width: s.sm),
              Flexible(
                child: ChatCardLine(
                  spans: [
                    reference,
                    if (ticket != null && status != null)
                      chatCardStrong(
                        context,
                        statusLabel(l, ticket.status),
                        status,
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (ticket != null) ...[
            ChatCardTitle(ticket.title),
            ChatCardLine(
              spans: [
                chatCardStrong(
                  context,
                  priorityLabel(ProviderType.zentao, ticket.priority),
                  priorityColor(c, ticket.priority),
                ),
                ?ticket.assignee,
              ],
            ),
          ] else ...[
            if (fallbackTitle case final title?) ChatCardTitle(title),
            ChatCardLine(
              spans: [
                if (fetch == null || fetch.isLoading)
                  l.chatMrLoading
                else if (failure is NotFoundFailure)
                  l.chatMrNoAccount(link.host)
                else
                  l.chatMrUnavailable,
              ],
            ),
          ],
        ],
      ),
    );
  }
}
