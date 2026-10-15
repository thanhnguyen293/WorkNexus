import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/shared/board/domain/entities/paged_view_state.dart';
import 'package:work_nexus/shared/board/domain/usecases/apply_view_pages.dart';
import 'package:work_nexus/shared/board/domain/usecases/plan_view_load.dart';
import 'package:work_nexus/shared/board/domain/usecases/should_auto_load.dart';
import 'package:work_nexus/shared/board/domain/value_objects/paging_policy.dart';

Ticket _t(String id) => Ticket(
  id: id,
  accountId: 'zt',
  projectId: 'p',
  providerType: ProviderType.zentao,
  externalKey: id,
  title: id,
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.todo,
  providerStatus: 'wait',
  sourceHash: 'h',
);

Result<ViewPage> _page(List<String> ids, {int total = 500}) => Ok(
  ViewPage(
    tickets: [for (final id in ids) _t(id)],
    total: total,
    hasMore: true,
  ),
);

void main() {
  group('PlanViewLoad', () {
    const plan = PlanViewLoad();

    test('a first load fetches page 1 only, even filtered', () {
      final p = plan(
        const ViewLoadRequest(state: PagedViewState(), filtered: true),
      )!;
      expect(p.pages, [1]);
      expect(p.loading.loading, isTrue);
    });

    test('a filtered board fans out, within the view', () {
      const started = PagedViewState(page: 1, total: 120);
      expect(
        plan(const ViewLoadRequest(state: started, filtered: true))!.pages,
        [2, 3],
      );
      const big = PagedViewState(page: 1, total: 5000);
      expect(
        plan(const ViewLoadRequest(state: big, filtered: true))!.pages,
        hasLength(kFilteredPagesPerLoad),
      );
      expect(plan(const ViewLoadRequest(state: big, filtered: false))!.pages, [
        2,
      ]);
    });

    test('an ask without new cards counts as dry; new cards reset it', () {
      const asked = PagedViewState(page: 1, total: 500, scanVisible: 3);
      final dry = plan(
        const ViewLoadRequest(state: asked, filtered: true, visible: 3),
      )!;
      expect(dry.loading.dryLoads, 1);
      final fresh = plan(
        ViewLoadRequest(
          state: dry.loading.copyWith(loading: false),
          filtered: true,
          visible: 5,
        ),
      )!;
      expect(fresh.loading.dryLoads, 0);
      expect(fresh.loading.scanVisible, 5);
    });

    test('nothing to plan while loading, failed or done', () {
      for (final state in [
        const PagedViewState(loading: true),
        const PagedViewState(failure: NetworkFailure('offline')),
        const PagedViewState(page: 2, hasMore: false),
      ]) {
        expect(plan(ViewLoadRequest(state: state, filtered: false)), isNull);
      }
    });
  });

  group('ApplyViewPages', () {
    test('folds pages in and keeps those before a failure', () {
      final next = const ApplyViewPages()(
        ViewPagesResult(
          state: const PagedViewState(page: 1, ids: {'a'}, loading: true),
          pages: [
            _page(['b']),
            const Err(NetworkFailure('offline')),
            _page(['c']),
          ],
        ),
      );
      expect(next.ids, {'a', 'b'});
      expect(next.page, 2);
      expect(next.loading, isFalse);
      expect(next.failure, isA<NetworkFailure>());
    });
  });

  group('ShouldAutoLoad', () {
    bool auto(PagedViewState s, {bool filtered = true, int visible = 0}) =>
        const ShouldAutoLoad()(
          AutoLoadQuery(state: s, filtered: filtered, visible: visible),
        );

    test(
      'a filtered column stops after its dry loads, unless cards turn up',
      () {
        const dry = PagedViewState(
          page: 3,
          scanVisible: 0,
          dryLoads: kMaxDryLoads,
        );
        expect(auto(dry), isFalse);
        expect(auto(dry, visible: 1), isTrue);
        expect(auto(dry, filtered: false), isTrue);
      },
    );

    test('never while a page loads or the view has ended', () {
      expect(
        auto(const PagedViewState(loading: true), filtered: false),
        isFalse,
      );
      expect(
        auto(const PagedViewState(hasMore: false), filtered: false),
        isFalse,
      );
    });
  });
}
