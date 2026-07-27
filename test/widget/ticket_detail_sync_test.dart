import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/di/service_locator.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/sync/data/sync_service.dart';
import 'package:work_nexus/features/task_detail/presentation/detail_providers.dart';

class _MockSyncService extends Mock implements SyncService {}

const _ticket = Ticket(
  id: 'zentao:bug:4808',
  accountId: 'zentao',
  projectId: '4',
  providerType: ProviderType.zentao,
  externalKey: '4808',
  externalType: 'bug',
  title: 'Duplicate post exposed after uploading video',
  body: '',
  priority: Priority.high,
  status: UnifiedStatus.todo,
  providerStatus: 'active',
  sourceHash: 'hash',
);

void main() {
  late _MockSyncService sync;

  setUpAll(() => registerFallbackValue(_ticket));

  setUp(() async {
    sync = _MockSyncService();
    await getIt.reset();
    getIt.registerSingleton<SyncService>(sync);
    when(
      () => sync.syncTicketDetail(any()),
    ).thenAnswer((_) async => const Ok(null));
  });

  tearDown(() => getIt.reset());

  Future<ProviderContainer> container() async {
    final c = ProviderContainer(
      overrides: [
        ticketsProvider.overrideWith((ref) => Stream.value(const [_ticket])),
      ],
    );
    addTearDown(c.dispose);
    // The ticket stream only runs while listened to, and the detail sync reads
    // the ticket out of it — so let it emit before the panel's sync is created.
    c.listen(ticketsProvider, (_, _) {});
    await c.read(ticketsProvider.future);
    return c;
  }

  test(
    'closing the panel disposes the sync, so the next open refetches',
    () async {
      final c = await container();

      final first = c.listen(ticketDetailSyncProvider(_ticket.id), (_, _) {});
      await c.read(ticketDetailSyncProvider(_ticket.id).future);
      first.close();
      await Future<void>.delayed(Duration.zero);

      final second = c.listen(ticketDetailSyncProvider(_ticket.id), (_, _) {});
      await c.read(ticketDetailSyncProvider(_ticket.id).future);
      second.close();

      verify(() => sync.syncTicketDetail(_ticket)).called(2);
    },
  );

  test('reopening the same ticket refetches its detail', () async {
    final c = await container();

    final sub = c.listen(ticketDetailSyncProvider(_ticket.id), (_, _) {});
    await c.read(ticketDetailSyncProvider(_ticket.id).future);

    // What the panel does on every open, so a reopen during the close animation
    // (provider not disposed yet) still hits the provider.
    c.invalidate(ticketDetailSyncProvider(_ticket.id));
    await c.read(ticketDetailSyncProvider(_ticket.id).future);
    sub.close();

    verify(() => sync.syncTicketDetail(_ticket)).called(2);
  });
}
