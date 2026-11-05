import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/locator.dart';
import '../../../core/di/providers.dart';
import '../../../core/domain/adapters/ticket_detail_service.dart';
import '../../../core/domain/entities/activity_event.dart';
import '../../../core/domain/entities/comment.dart';
import '../../../core/domain/entities/provider_entity.dart';
import '../../../core/domain/entities/ticket.dart';
import '../../../core/domain/repositories/activity_repository.dart';
import '../../../core/domain/repositories/comment_repository.dart';
import '../../../core/error/result.dart';

enum DetailTab { original, translation }

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

/// On opening a ticket, pull its full detail + comments from the provider into
/// drift. The panel `watch`es this to show a refresh indicator; the actual
/// content updates flow through the reactive ticket/comment streams.
///
/// `autoDispose`, and invalidated by the panel on every open, so a ticket's
/// detail is always fetched fresh — never served from a previous open's result.
final ticketDetailSyncProvider = FutureProvider.autoDispose
    .family<void, String>((ref, id) async {
      final ticket = ref.read(ticketByIdProvider(id));
      if (ticket == null) return;
      await getIt<TicketDetailService>().syncTicketDetail(ticket);
    });

/// A still frame of a ticket's video attachment (null: none can be shown).
final attachmentThumbnailProvider = FutureProvider.autoDispose
    .family<Uint8List?, (Ticket, TicketAttachment)>(
      (ref, key) =>
          getIt<TicketDetailService>().attachmentThumbnail(key.$1, key.$2),
    );

/// Disk taken by downloaded ticket attachments and kept stream videos.
final attachmentStorageBytesProvider = FutureProvider.autoDispose<Result<int>>(
  (ref) => getIt<TicketDetailService>().attachmentStorageBytes(),
);
