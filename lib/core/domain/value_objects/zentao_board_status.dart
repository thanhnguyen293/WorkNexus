import '../entities/ticket.dart';
import 'provider_type.dart';
import 'unified_status.dart';
import 'zentao_bug_column.dart';
import 'zentao_task_column.dart';

ZenTaoBugColumn zentaoBugColumnFor(Ticket ticket) {
  final raw = ticket.providerStatus.toLowerCase();
  final resolution = zentaoBugResolution(ticket);
  if (raw == 'closed') return ZenTaoBugColumn.closed;
  if (raw == 'resolved') {
    if (resolution == 'postponed') return ZenTaoBugColumn.postponed;
    if (resolution == 'fixed' || resolution.isEmpty) {
      return ZenTaoBugColumn.resolvedVerify;
    }
    return ZenTaoBugColumn.nonFix;
  }
  if (ticket.status == UnifiedStatus.inbox) {
    return ZenTaoBugColumn.newUnconfirmed;
  }
  return ZenTaoBugColumn.confirmedToFix;
}

String zentaoBugResolution(Ticket ticket) {
  for (final label in ticket.labels) {
    final lower = label.toLowerCase();
    if (lower.startsWith('resolution:')) {
      return lower.substring('resolution:'.length).trim();
    }
  }
  return '';
}

ZenTaoTaskColumn zentaoTaskColumnFor(Ticket ticket) {
  final raw = ticket.providerStatus.toLowerCase();
  return switch (raw) {
    'doing' => ZenTaoTaskColumn.inProgress,
    'pause' => ZenTaoTaskColumn.paused,
    'done' => ZenTaoTaskColumn.doneVerify,
    'closed' => ZenTaoTaskColumn.closed,
    'cancel' => ZenTaoTaskColumn.canceled,
    _ when ticket.status == UnifiedStatus.inprogress =>
      ZenTaoTaskColumn.inProgress,
    _ when ticket.status == UnifiedStatus.blocked => ZenTaoTaskColumn.paused,
    _ when ticket.status == UnifiedStatus.review => ZenTaoTaskColumn.doneVerify,
    _ when ticket.status == UnifiedStatus.done => ZenTaoTaskColumn.closed,
    _ => ZenTaoTaskColumn.notStarted,
  };
}

/// The board column a ZenTao bug or task sits in, by name
/// (`ZenTaoBugColumn` / `ZenTaoTaskColumn`) — the status a table row shows,
/// and what the Status filter matches. Null for any other ticket.
String? zentaoStatusOf(Ticket ticket) {
  if (ticket.providerType != ProviderType.zentao) return null;
  return switch ((ticket.externalType ?? '').toLowerCase()) {
    'bug' => zentaoBugColumnFor(ticket).name,
    'task' => zentaoTaskColumnFor(ticket).name,
    _ => null,
  };
}
