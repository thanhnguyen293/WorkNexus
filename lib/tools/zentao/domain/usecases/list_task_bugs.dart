import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';

/// The bugs related to ZenTao task [task] among [tickets]: the account's bugs
/// whose `task` is its id (ZenTao keeps the link on the bug). Newest first.
class ListTaskBugs {
  const ListTaskBugs();

  List<Ticket> call({required Ticket task, required Iterable<Ticket> tickets}) {
    final taskId = task.externalKey;
    final bugs = [
      for (final t in tickets)
        if (t.providerType == ProviderType.zentao &&
            t.accountId == task.accountId &&
            t.providerEntity is ZenTaoBugEntity &&
            (t.providerEntity as ZenTaoBugEntity).task == taskId)
          t,
    ];
    bugs.sort((a, b) => _number(b).compareTo(_number(a)));
    return bugs;
  }

  static int _number(Ticket t) => int.tryParse(t.externalKey) ?? 0;
}
