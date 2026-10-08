import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/adapters/zentao_ticket_service.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/result.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/platform/open_external.dart';
import '../../domain/usecases/find_linked_ticket.dart';
import '../providers/chat_providers.dart';

/// Loads ZenTao tickets that chat links point to but the board has not
/// synced.
final zenTaoTicketServiceProvider = Provider<ZenTaoTicketService>(
  (ref) => getIt<ZenTaoTicketService>(),
);

/// The synced ZenTao ticket [url] points to, if any (watched, so a card
/// updates when the ticket syncs).
Ticket? watchLinkedTicket(WidgetRef ref, String url) => ref
    .watch(chatControllerProvider)
    .linkedTicket(url, ref.watch(ticketsProvider).value ?? const []);

/// Opens a link tapped in chat. A ZenTao bug/task/story opens in the detail
/// panel beside the chat — fetched from ZenTao first when the board has not
/// synced it; anything else (or a ticket that cannot be loaded) opens in the
/// browser.
Future<void> openChatLink(WidgetRef ref, String url) async {
  final opener = ref.read(openTicketIdProvider.notifier);
  final ticket = ref
      .read(chatControllerProvider)
      .linkedTicket(url, ref.read(ticketsProvider).value ?? const []);
  if (ticket != null) {
    opener.open(ticket.id);
    return;
  }
  final link = FindLinkedTicket.parse(url);
  if (link == null) {
    await openExternally(url);
    return;
  }
  final fetched = await ref
      .read(zenTaoTicketServiceProvider)
      .fetchZenTaoTicket(host: link.host, type: link.type, id: link.id);
  switch (fetched) {
    case Ok(:final value):
      opener.open(value);
    case Err():
      await openExternally(url);
  }
}
