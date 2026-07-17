import '../../error/result.dart';
import '../entities/activity_event.dart';
import '../entities/comment.dart';
import '../entities/ticket.dart';
import '../value_objects/provider_type.dart';

/// Outcome of a connection test.
class ConnectionCheck {
  const ConnectionCheck({
    required this.ok,
    this.account,
    this.serverVersion,
    this.error,
  });

  final bool ok;
  final String? account;
  final String? serverVersion;
  final String? error;
}

/// A page of assigned tickets plus an opaque cursor for incremental sync.
class TicketPage {
  const TicketPage({required this.tickets, this.nextCursor});

  final List<Ticket> tickets;
  final String? nextCursor;
}

/// A user that a ticket can be assigned to.
class ProviderUser {
  const ProviderUser({required this.account, required this.displayName});

  /// The provider login/account (what `assignedTo` expects).
  final String account;

  /// Human-friendly name shown in pickers.
  final String displayName;
}

/// The contract every ticket source implements. An instance is bound to a single
/// [Account] (base URL + credentials), so returned entities are already stamped
/// with that account's id. Add a provider = implement this once (ZenTao first).
abstract class ProviderAdapter {
  ProviderType get providerType;

  /// Verify credentials/reachability without importing data.
  Future<Result<ConnectionCheck>> testConnection();

  /// Tickets assigned to the current user. [sinceCursor] enables incremental sync.
  Future<Result<TicketPage>> listAssignedTickets({String? sinceCursor});

  /// Refetch full detail for a ticket (normalized).
  Future<Result<Ticket>> getTicket(Ticket ticket);

  /// Comments / action history for a ticket.
  Future<Result<List<Comment>>> listComments(Ticket ticket);

  /// Post a comment back to the provider; returns the created comment.
  Future<Result<Comment>> postComment(Ticket ticket, String body);

  /// Provider-side activity/history timeline.
  Future<Result<List<ActivityEvent>>> listActivity(Ticket ticket);

  /// Users the ticket can be (re)assigned to.
  Future<Result<List<ProviderUser>>> listUsers();

  /// Reassign the ticket to [assignee] (a provider account), with an optional note.
  Future<Result<bool>> assignTicket(
    Ticket ticket, {
    required String assignee,
    String? comment,
  });

  /// Resolve a bug with the given [resolution] (and optional build / next
  /// assignee / note). Only meaningful for bug-type tickets.
  Future<Result<bool>> resolveBug(
    Ticket ticket, {
    required String resolution,
    String? resolvedBuild,
    String? assignee,
    String? comment,
  });

  /// Reopen/activate a previously resolved or closed bug.
  Future<Result<bool>> activateBug(
    Ticket ticket, {
    String? openedBuild,
    String? assignee,
    String? comment,
  });
}
