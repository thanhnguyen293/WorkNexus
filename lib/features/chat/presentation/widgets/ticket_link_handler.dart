import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/platform/link_router.dart';
import '../../domain/usecases/find_linked_ticket.dart';
import '../providers/chat_providers.dart';
import 'chat_links.dart';

/// Makes a ZenTao bug / task / story link tapped anywhere in the app (a
/// description, a comment, a notification) open in the ticket detail panel
/// instead of a mini app or the browser. Links to anything else pass through
/// to the next stages of the [LinkRouter]. It sits in the chat feature because
/// that is where a link is matched to a ticket ([FindLinkedTicket]).
class TicketLinkHandler extends ConsumerStatefulWidget {
  const TicketLinkHandler({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TicketLinkHandler> createState() => _TicketLinkHandlerState();
}

class _TicketLinkHandlerState extends ConsumerState<TicketLinkHandler>
    implements LinkHandler {
  @override
  void initState() {
    super.initState();
    linkRouter.register(LinkStage.app, this);
  }

  @override
  void dispose() {
    linkRouter.unregister(LinkStage.app, this);
    super.dispose();
  }

  @override
  bool handle(String url) {
    final known = ref
        .read(chatControllerProvider)
        .linkedTicket(url, ref.read(ticketsProvider).value ?? const []);
    if (known == null && FindLinkedTicket.parse(url) == null) return false;
    unawaited(openChatLink(ref, url));
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
