import 'dart:typed_data';

import '../../error/result.dart';
import '../entities/provider_entity.dart';
import '../entities/ticket.dart';
import '../value_objects/media_request.dart';
import 'provider_adapter.dart';

/// Presentation-facing contract for generic ticket detail actions (detail sync,
/// image fetching, caching attachments, comments, assignment, and reviewers).
abstract interface class TicketDetailService {
  Future<Result<void>> syncTicketDetail(Ticket ticket);

  Future<Uint8List?> fetchTicketImage(Ticket ticket, String url);

  Future<String?> cacheAttachment(Ticket ticket, TicketAttachment att);

  /// How a player streams video attachment [att] (through a local caching
  /// proxy); null when it can't, and the file must be downloaded first.
  Future<MediaRequest?> attachmentStream(Ticket ticket, TicketAttachment att);

  /// Bytes the downloaded attachments and kept stream videos take.
  Future<Result<int>> attachmentStorageBytes();

  /// Deletes the downloaded attachments and kept stream videos.
  Future<Result<void>> clearAttachmentStorage();

  /// A still frame of a video attachment, downloading it when it is small
  /// enough; null when the video is too big or no frame can be made.
  Future<Uint8List?> attachmentThumbnail(Ticket ticket, TicketAttachment att);

  Future<String?> saveAttachmentToDownloads(
    String localCachedPath,
    String suggestedFileName,
  );

  Future<Result<void>> postComment(Ticket ticket, String body);

  Future<Result<void>> assignTicket(
    Ticket ticket, {
    required String assignee,
    String? comment,
  });

  Future<Result<void>> setReviewers(Ticket ticket, List<String> logins);

  Future<Result<List<ProviderUser>>> listUsers(Ticket ticket);
}
