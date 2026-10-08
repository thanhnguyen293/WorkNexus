import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/platform/open_external.dart';
import '../providers/chat_providers.dart';

/// The synced ZenTao ticket [url] points to, if any (watched, so a card
/// updates when the ticket syncs).
Ticket? watchLinkedTicket(WidgetRef ref, String url) => ref
    .watch(chatControllerProvider)
    .linkedTicket(url, ref.watch(ticketsProvider).value ?? const []);

/// Opens a link tapped in chat: a synced ZenTao ticket opens in the detail
/// panel beside the chat; anything else in the browser.
void openChatLink(WidgetRef ref, String url) {
  final ticket = ref
      .read(chatControllerProvider)
      .linkedTicket(url, ref.read(ticketsProvider).value ?? const []);
  if (ticket == null) {
    openExternally(url);
    return;
  }
  ref.read(openTicketIdProvider.notifier).open(ticket.id);
}
