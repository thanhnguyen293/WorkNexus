import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import 'build_zentao_bug_board.dart';
import 'build_zentao_task_board.dart';

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
