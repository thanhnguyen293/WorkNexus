import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/domain/entities/activity_event.dart';
import '../../../core/domain/entities/comment.dart';
import '../../../core/domain/entities/dev_link.dart';
import '../../../core/domain/repositories/activity_repository.dart';
import '../../../core/domain/repositories/comment_repository.dart';
import '../../../core/domain/repositories/dev_link_repository.dart';
import '../../sync/data/sync_service.dart';

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
  (ref, id) => getIt<CommentRepository>().watchComments(id),
);

final activityProvider = StreamProvider.family<List<ActivityEvent>, String>(
  (ref, id) => getIt<ActivityRepository>().watchActivity(id),
);

final devLinksProvider = StreamProvider.family<List<DevLink>, String>(
  (ref, id) => getIt<DevLinkRepository>().watchDevLinks(id),
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
  await getIt<SyncService>().syncTicketDetail(ticket);
});
