import 'dart:typed_data';

import '../../error/result.dart';
import '../entities/provider_entity.dart';
import '../entities/ticket.dart';
import 'provider_adapter.dart';

/// What the ticket detail panel needs from the provider behind a ticket, for
/// any provider: refreshing its detail, inline images and attachments, and the
/// common write actions. Implemented in the data layer.
abstract interface class TicketDetailService {
  /// Pulls the ticket's full detail, comments and activity into the database.
  Future<Result<void>> syncTicketDetail(Ticket ticket);

  /// Bytes of an inline image in the ticket's rich text, or null.
  Future<Uint8List?> fetchTicketImage(Ticket ticket, String url);

  /// Downloads [attachment] to a session cache; returns its local path or null.
  Future<String?> cacheAttachment(Ticket ticket, TicketAttachment attachment);

  /// Copies a cached attachment to the Downloads folder; returns the new path.
  Future<String?> saveAttachmentToDownloads(String cachedPath, String name);

  Future<Result<void>> postComment(Ticket ticket, String body);

  /// The people [ticket] can be assigned to.
  Future<Result<List<ProviderUser>>> listUsers(Ticket ticket);

  Future<Result<void>> assignTicket(
    Ticket ticket, {
    required String assignee,
    String? comment,
  });

  /// Sets the reviewers of a merge/pull request (GitLab replaces the set,
  /// GitHub requests the given logins).
  Future<Result<void>> setReviewers(Ticket ticket, List<String> logins);
}
