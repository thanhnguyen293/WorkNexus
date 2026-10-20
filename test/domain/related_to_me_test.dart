import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/shared/board/domain/usecases/filter_tickets.dart';
import 'package:work_nexus/shared/board/domain/usecases/is_related_to_me.dart';
import 'package:work_nexus/shared/board/domain/usecases/merge_view_pages.dart';
import 'package:work_nexus/shared/board/domain/value_objects/saved_view.dart';

const _me = Account(
  id: 'zt',
  handle: 'thanh',
  workspaceId: 'w',
  providerType: ProviderType.zentao,
);

Ticket _ticket(
  String id, {
  String? assignee,
  TicketProviderEntity? entity,
  UnifiedStatus status = UnifiedStatus.todo,
  String providerStatus = 'active',
}) => Ticket(
  id: id,
  accountId: 'zt',
  projectId: 'p',
  providerType: ProviderType.zentao,
  externalKey: id,
  externalType: 'Bug',
  title: 't',
  body: '',
  priority: Priority.medium,
  status: status,
  providerStatus: providerStatus,
  sourceHash: 'h',
  assignee: assignee,
  providerEntity: entity,
);

void main() {
  group('IsRelatedToMe', () {
    const related = IsRelatedToMe();

    test('a bug assigned to, opened by or resolved by me', () {
      expect(related(_ticket('a', assignee: 'thanh'), _me), isTrue);
      expect(
        related(
          _ticket(
            'o',
            assignee: 'an',
            entity: const TicketProviderEntity.zentaoBug(
              openedByHandle: 'thanh',
            ),
          ),
          _me,
        ),
        isTrue,
      );
      expect(
        related(
          _ticket(
            'r',
            assignee: 'an',
            entity: const TicketProviderEntity.zentaoBug(
              resolvedByHandle: 'thanh',
            ),
          ),
          _me,
        ),
        isTrue,
      );
    });

    test('a task opened or finished by me', () {
      expect(
        related(
          _ticket(
            'f',
            entity: const TicketProviderEntity.zentaoTask(
              finishedByHandle: 'thanh',
            ),
          ),
          _me,
        ),
        isTrue,
      );
    });

    test("not someone else's", () {
      expect(
        related(
          _ticket(
            'x',
            assignee: 'an',
            entity: const TicketProviderEntity.zentaoBug(
              openedByHandle: 'thanhle',
              resolvedByHandle: 'an',
            ),
          ),
          _me,
        ),
        isFalse,
      );
    });

    test('the related view keeps them, but not closed ones', () {
      const opener = TicketProviderEntity.zentaoBug(openedByHandle: 'thanh');
      final mine = savedViewMatches(
        SavedView.related,
        _ticket('o', entity: opener),
        DateTime(2026),
        _me,
      );
      final closed = savedViewMatches(
        SavedView.related,
        _ticket(
          'c',
          entity: opener,
          status: UnifiedStatus.done,
          providerStatus: 'closed',
        ),
        DateTime(2026),
        _me,
      );
      expect(mine, isTrue);
      expect(closed, isFalse);
    });
  });

  group('MergeViewPages', () {
    const merge = MergeViewPages();
    ViewPage page(List<String> ids, {bool more = false}) => ViewPage(
      tickets: [for (final id in ids) _ticket(id)],
      total: ids.length,
      hasMore: more,
    );

    test('lists a ticket once, with more while any view has more', () {
      final merged = merge([
        Ok(page(['1', '2'], more: true)),
        Ok(page(['2', '3'])),
      ]);
      final value = merged.valueOrNull!;
      expect(value.tickets.map((t) => t.id), ['1', '2', '3']);
      expect(value.hasMore, isTrue);
      expect(value.total, 4);
    });

    test('fails when one view fails', () {
      final merged = merge([
        Ok(page(['1'])),
        const Err(NetworkFailure('down')),
      ]);
      expect(merged, isA<Err<ViewPage>>());
    });
  });
}
