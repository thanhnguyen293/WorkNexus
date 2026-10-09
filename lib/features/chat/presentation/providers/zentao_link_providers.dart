import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/usecases/find_linked_ticket.dart';

/// How long a fetched ticket is trusted before a card seen again fetches it
/// anew.
const _kFresh = Duration(minutes: 5);

/// Fetches the ticket a ZenTao link points to (and stores it); its id, or
/// why it could not be loaded.
final chatZenTaoFetchProvider = FutureProvider.autoDispose
    .family<Result<String>, String>((ref, url) async {
      final keep = ref.keepAlive();
      final timer = Timer(_kFresh, keep.close);
      ref.onDispose(timer.cancel);
      final link = FindLinkedTicket.parse(url);
      if (link == null) {
        return const Err(UnexpectedFailure('Not a ZenTao ticket link'));
      }
      return ref
          .watch(zenTaoTicketServiceProvider)
          .fetchZenTaoTicket(host: link.host, type: link.type, id: link.id);
    });

/// The ticket a ZenTao link points to: the synced one, else the one fetched
/// for it (watched, so a card updates when it syncs or arrives).
final chatZenTaoTicketProvider = Provider.autoDispose.family<Ticket?, String>((
  ref,
  url,
) {
  // Until the stored tickets are read, a synced one may still answer the
  // link: fetching now would ask ZenTao for nothing.
  final tickets = ref.watch(ticketsProvider).value;
  if (tickets == null) return null;
  if (const FindLinkedTicket()(url, tickets) case final synced?) return synced;
  final fetched = ref.watch(chatZenTaoFetchProvider(url)).value;
  if (fetched case Ok(:final value)) {
    return tickets.where((t) => t.id == value).firstOrNull;
  }
  return null;
});
