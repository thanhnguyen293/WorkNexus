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
  const ProviderUser({
    required this.account,
    required this.displayName,
    this.avatarUrl,
  });

  /// The provider login/account (what `assignedTo` expects).
  final String account;

  /// Human-friendly name shown in pickers.
  final String displayName;

  /// Provider-hosted avatar, when available.
  final String? avatarUrl;
}

/// A provider label available for assignment to a ticket.
class ProviderLabelOption {
  const ProviderLabelOption({required this.name, this.color});

  final String name;
  final String? color;
}

/// A provider milestone available for assignment to a ticket.
class ProviderMilestoneOption {
  const ProviderMilestoneOption({required this.id, required this.title});

  final int id;
  final String title;
}

/// A provider-side product/container that can scope ticket sync.
class ProviderProduct {
  const ProviderProduct({
    required this.id,
    required this.name,
    required this.accountId,
  });

  final String id;
  final String name;
  final String accountId;
}

/// A provider-side project that groups executions (ZenTao `Project`).
class ProviderProject {
  const ProviderProject({
    required this.id,
    required this.name,
    required this.accountId,
  });

  final String id;
  final String name;
  final String accountId;
}

/// A provider-side execution (sprint/iteration) that scopes task sync. Belongs
/// to a [ProviderProject] and holds the tasks shown on the native task board.
class ProviderExecution {
  const ProviderExecution({
    required this.id,
    required this.name,
    required this.projectId,
    required this.accountId,
  });

  final String id;
  final String name;
  final String projectId;
  final String accountId;
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

  /// Products/containers available to this account.
  Future<Result<List<ProviderProduct>>> listProducts();

  /// Bugs scoped to one provider product/container. [browseType] optionally
  /// selects a provider-defined server-side view (e.g. ZenTao's
  /// `unclosed`/`assigntome`/`resolvedbyme` bug tabs); null means all bugs.
  Future<Result<TicketPage>> listProductBugs(
    String productId, {
    String? browseType,
  });

  /// Projects available to this account (each groups executions).
  Future<Result<List<ProviderProject>>> listProjects();

  /// Executions within one project.
  Future<Result<List<ProviderExecution>>> listProjectExecutions(
    String projectId,
  );

  /// Tasks scoped to one execution/container.
  Future<Result<TicketPage>> listExecutionTasks(String executionId);

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

  /// Confirm a New/Unconfirmed bug (ZenTao sets `confirmed = 1`), optionally
  /// (re)assigning it and attaching a note. Only meaningful for bug-type
  /// tickets; moves the bug from New/Unconfirmed into Confirmed/To Fix.
  Future<Result<bool>> confirmBug(
    Ticket ticket, {
    String? assignee,
    String? comment,
  });
}
