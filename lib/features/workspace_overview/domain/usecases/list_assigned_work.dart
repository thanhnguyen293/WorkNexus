import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../entities/assigned_work_item.dart';

class ListAssignedWorkInput {
  const ListAssignedWorkInput({
    required this.tickets,
    required this.accounts,
    this.now,
  });

  final Iterable<Ticket> tickets;
  final Iterable<Account> accounts;
  final DateTime? now;
}

/// Pure use case: (tickets, accounts of the active workspace, now) → sorted open items.
/// Assigned  = ticket.assignee equals the owning account's handle (case-insensitive)
/// Reviewer  = handle ∈ providerEntity.reviewers (PR/MR only)
/// Open      = status not in {done, closed} (and raw status not in finished statuses)
/// Sort      = overdue first → due asc → updatedAt desc
class ListAssignedWork {
  const ListAssignedWork();

  static const _finishedStatuses = {
    'done',
    'closed',
    'cancel',
    'resolved',
    'merged',
  };

  static bool isOpen(Ticket t) {
    if (t.status == UnifiedStatus.done) return false;
    final raw = t.providerStatus.trim().toLowerCase();
    if (_finishedStatuses.contains(raw)) return false;
    if (t.providerEntity case final GitHubItemEntity gh) {
      if (gh.merged == true) return false;
    }
    return true;
  }

  static String formatDisplayKey(Ticket t) {
    final key = t.externalKey;
    final type = t.externalType?.trim().toLowerCase();
    return switch (t.providerType) {
      ProviderType.zentao => switch (type) {
        'bug' => 'BUG-$key',
        'task' => 'TASK-$key',
        'story' => 'STORY-$key',
        _ => key,
      },
      ProviderType.gitlab => switch (type) {
        'mergerequest' => '!$key',
        _ => '#$key',
      },
      ProviderType.github => '#$key',
      ProviderType.jira => key,
    };
  }

  static DateTime? extractDue(Ticket t) {
    if (t.providerEntity case ZenTaoBugEntity(:final deadline?)) {
      if (_parseDue(deadline) case final due?) return due;
    }
    for (final l in t.labels) {
      final raw = l.startsWith('deadline:')
          ? l.substring(9)
          : l.startsWith('due:')
          ? l.substring(4)
          : null;
      if (raw != null) {
        if (_parseDue(raw) case final due?) return due;
      }
    }
    return null;
  }

  /// [raw] as a due moment, or null for none. ZenTao writes "no deadline" as
  /// `0000-00-00`, which [DateTime.tryParse] reads as a date in year -1 — so
  /// always overdue. A bare date is due by the end of that day, not at its
  /// first second.
  static DateTime? _parseDue(String raw) {
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null || parsed.year < 1) return null;
    if (raw.contains(':')) return parsed;
    return DateTime(
      parsed.year,
      parsed.month,
      parsed.day + 1,
    ).subtract(const Duration(seconds: 1));
  }

  List<AssignedWorkItem> call(ListAssignedWorkInput input) {
    final accountMap = {for (final a in input.accounts) a.id: a};
    final now = input.now ?? DateTime.now();
    final items = <AssignedWorkItem>[];

    for (final ticket in input.tickets) {
      if (!isOpen(ticket)) continue;

      final account = accountMap[ticket.accountId];
      if (account == null) continue;

      final handle = account.handle.trim().toLowerCase();
      if (handle.isEmpty) continue;

      final isAssignee = ticket.assignee?.trim().toLowerCase() == handle;

      final isReviewer = switch (ticket.providerEntity) {
        // Logins, as the account knows its user; items stored before they
        // were kept only have the reviewers' display names.
        final GitHubItemEntity gh =>
          (gh.reviewerLogins.isNotEmpty ? gh.reviewerLogins : gh.reviewers).any(
            (r) => r.trim().toLowerCase() == handle,
          ),
        final GitLabItemEntity gl => gl.reviewers.any(
          (r) => r.trim().toLowerCase() == handle,
        ),
        _ => false,
      };

      if (!isAssignee && !isReviewer) continue;

      final reason = isAssignee
          ? AssignedReason.assignee
          : AssignedReason.reviewer;
      final due = extractDue(ticket);

      items.add(
        AssignedWorkItem(
          ticketId: ticket.id,
          provider: ticket.providerType,
          displayKey: formatDisplayKey(ticket),
          title: ticket.title,
          status: ticket.status,
          statusLabel: ticket.providerStatus,
          reason: reason,
          due: due,
          updatedAt: ticket.updatedAt,
        ),
      );
    }

    items.sort((a, b) => _compare(a, b, now));
    return items;
  }

  static int _compare(AssignedWorkItem a, AssignedWorkItem b, DateTime now) {
    final aOverdue = a.due != null && a.due!.isBefore(now);
    final bOverdue = b.due != null && b.due!.isBefore(now);

    if (aOverdue != bOverdue) {
      return aOverdue ? -1 : 1;
    }

    if (aOverdue && bOverdue) {
      final dueCmp = a.due!.compareTo(b.due!);
      if (dueCmp != 0) return dueCmp;
      return _compareUpdated(a, b);
    }

    // Neither is overdue
    if (a.due != null && b.due != null) {
      final dueCmp = a.due!.compareTo(b.due!);
      if (dueCmp != 0) return dueCmp;
      return _compareUpdated(a, b);
    }

    if (a.due != null) return -1;
    if (b.due != null) return 1;

    return _compareUpdated(a, b);
  }

  static int _compareUpdated(AssignedWorkItem a, AssignedWorkItem b) {
    final aUp = a.updatedAt;
    final bUp = b.updatedAt;
    if (aUp != null && bUp != null) {
      final cmp = bUp.compareTo(aUp);
      if (cmp != 0) return cmp;
    } else if (aUp != null) {
      return -1;
    } else if (bUp != null) {
      return 1;
    }
    return a.ticketId.compareTo(b.ticketId);
  }
}
