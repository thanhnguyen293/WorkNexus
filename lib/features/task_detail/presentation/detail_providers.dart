import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/domain/entities/activity_event.dart';
import '../../../core/domain/entities/comment.dart';
import '../../../core/domain/entities/dev_link.dart';

enum DetailTab { original, translation, comments, development }

/// Which detail tab is active (resets to original when a new ticket opens).
final detailTabProvider = NotifierProvider<DetailTabController, DetailTab>(
  DetailTabController.new,
);

class DetailTabController extends Notifier<DetailTab> {
  @override
  DetailTab build() => DetailTab.original;
  void set(DetailTab tab) => state = tab;
}

final commentsProvider = StreamProvider.family<List<Comment>, String>(
  (ref, id) => ref.watch(commentRepositoryProvider).watchComments(id),
);

final activityProvider = StreamProvider.family<List<ActivityEvent>, String>(
  (ref, id) => ref.watch(activityRepositoryProvider).watchActivity(id),
);

final devLinksProvider = StreamProvider.family<List<DevLink>, String>(
  (ref, id) => ref.watch(devLinkRepositoryProvider).watchDevLinks(id),
);

/// One-shot: on opening a ticket, pull its full detail + comments from the
/// provider into drift. The panel `watch`es this to show a refresh indicator;
/// the actual content updates flow through the reactive ticket/comment streams.
/// Cached per ticket id, so it fetches once per app session unless invalidated.
final ticketDetailSyncProvider = FutureProvider.family<void, String>((
  ref,
  id,
) async {
  final ticket = ref.read(ticketByIdProvider(id));
  if (ticket == null) return;
  await ref.read(syncServiceProvider).syncTicketDetail(ticket);
});
