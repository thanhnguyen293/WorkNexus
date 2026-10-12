import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/error/result.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/navigation/open_zentao_ticket.dart';
import '../../../../core/platform/open_external.dart';
import '../../domain/usecases/find_linked_ticket.dart';
import '../providers/chat_providers.dart';

/// Opens a link tapped in chat. A ZenTao bug/task/story opens in the detail
/// panel beside the chat — fetched from ZenTao first when the board has not
/// synced it; anything else (or a ticket that cannot be loaded) opens in the
/// browser.
Future<void> openChatLink(WidgetRef ref, String url) async {
  final nav = ref.read(appNavProvider.notifier);
  final ticket = ref
      .read(chatControllerProvider)
      .linkedTicket(url, ref.read(ticketsProvider).value ?? const []);
  if (ticket != null) {
    nav.openTicket(ticket.id);
    return;
  }
  final link = FindLinkedTicket.parse(url);
  if (link == null) {
    await openExternally(url);
    return;
  }
  final opened = await openZenTaoTicket(
    ref,
    host: link.host,
    type: link.type,
    id: link.id,
  );
  if (opened is Err) await openExternally(url);
}
