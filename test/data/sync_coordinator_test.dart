import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/data/mappers/mappers.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter_registry.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/platform/credential_store.dart';
import 'package:work_nexus/shared/sync/data/source_list_cache.dart';
import 'package:work_nexus/shared/sync/data/sync_coordinator.dart';

class _MemoryCredentialStore extends CredentialStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String ref) async => values[ref];

  @override
  Future<void> write(String ref, String secret) async => values[ref] = secret;
}

class _MockAdapter extends Mock implements ProviderAdapter {}

/// Builds a fresh adapter per call and remembers the secret it was given.
class _RecordingRegistry implements ProviderAdapterRegistry {
  final secrets = <String>[];
  final adapters = <_MockAdapter>[];

  @override
  ProviderAdapter? createAdapter(
    Account account,
    String secret, {
    dynamic zenClient,
  }) {
    secrets.add(secret);
    final adapter = _MockAdapter();
    adapters.add(adapter);
    return adapter;
  }
}

const _account = Account(
  id: 'gl-acc',
  workspaceId: 'ws',
  providerType: ProviderType.gitlab,
  handle: 'me',
  baseUrl: 'https://gitlab.example',
  credentialsRef: 'secret:gl-acc',
);

const _ticket = Ticket(
  id: 'gl-acc:issue:1',
  accountId: 'gl-acc',
  projectId: 'gl-acc:group/repo',
  providerType: ProviderType.gitlab,
  externalKey: '1',
  externalType: 'Issue',
  title: 'Issue',
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.todo,
  providerStatus: 'opened',
  sourceHash: 'h',
);

void main() {
  late AppDatabase db;
  late _MemoryCredentialStore credentials;
  late _RecordingRegistry registry;
  late SyncCoordinator coordinator;

  setUpAll(() => registerFallbackValue(_ticket));

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    credentials = _MemoryCredentialStore()..values['secret:gl-acc'] = 'old';
    registry = _RecordingRegistry();
    coordinator = SyncCoordinator(db, credentials, registry: registry);
    await coordinator.upsert(_account, [_ticket]);
  });

  tearDown(() => db.close());

  group('adapter pool', () {
    test('every path for an account shares one adapter', () async {
      final first = await coordinator.adapterFor('gl-acc');
      final second = await coordinator.adapterFor('gl-acc');

      expect(identical(first, second), isTrue);
      expect(registry.secrets, ['old']);
    });

    test('a re-authenticated account gets an adapter with the new '
        'secret', () async {
      final before = await coordinator.adapterFor('gl-acc');
      credentials.values['secret:gl-acc'] = 'new';
      final after = await coordinator.adapterFor('gl-acc');

      expect(identical(before, after), isFalse);
      expect(registry.secrets, ['old', 'new']);
    });

    test('a removed account no longer serves its adapter', () async {
      await coordinator.adapterFor('gl-acc');
      credentials.values.remove('secret:gl-acc');

      expect(await coordinator.adapterFor('gl-acc'), isNull);
    });
  });

  group('runOptimisticAction', () {
    Future<Ticket> stored() async =>
        ticketFromRow(await db.select(db.tickets).getSingle());

    test('keeps the action\'s outcome when only the refresh fails', () async {
      final adapter = await coordinator.adapterFor('gl-acc') as _MockAdapter;
      when(() => adapter.getTicket(any())).thenThrow(Exception('offline'));
      final optimistic = _ticket.copyWith(status: UnifiedStatus.done);

      await expectLater(
        coordinator.runOptimisticAction(
          _ticket,
          optimistic,
          () async => const Ok(null),
        ),
        throwsException,
      );

      expect((await stored()).status, UnifiedStatus.done);
    });

    test('rolls back when the action itself throws', () async {
      final optimistic = _ticket.copyWith(status: UnifiedStatus.done);

      await expectLater(
        coordinator.runOptimisticAction(
          _ticket,
          optimistic,
          () async => throw Exception('rejected'),
        ),
        throwsException,
      );

      expect((await stored()).status, UnifiedStatus.todo);
    });
  });

  group('fetchTicketImage', () {
    Future<_MockAdapter> adapter() async =>
        await coordinator.adapterFor('gl-acc') as _MockAdapter;

    test(
      'an image the provider has not is not asked for again at once',
      () async {
        final a = await adapter();
        when(
          () => a.fetchBytes(
            any(),
            projectPath: any(named: 'projectPath'),
            projectId: any(named: 'projectId'),
          ),
        ).thenAnswer((_) async => null);

        await coordinator.fetchTicketImage(_ticket, 'https://x/a.png');
        await coordinator.fetchTicketImage(_ticket, 'https://x/a.png');

        verify(
          () => a.fetchBytes(
            any(),
            projectPath: any(named: 'projectPath'),
            projectId: any(named: 'projectId'),
          ),
        ).called(1);
      },
    );

    test('a failed request is asked again', () async {
      final a = await adapter();
      when(
        () => a.fetchBytes(
          any(),
          projectPath: any(named: 'projectPath'),
          projectId: any(named: 'projectId'),
        ),
      ).thenThrow(Exception('offline'));

      await coordinator.fetchTicketImage(_ticket, 'https://x/a.png');
      await coordinator.fetchTicketImage(_ticket, 'https://x/a.png');

      verify(
        () => a.fetchBytes(
          any(),
          projectPath: any(named: 'projectPath'),
          projectId: any(named: 'projectId'),
        ),
      ).called(2);
    });
  });

  test(
    'a project list fetched without program names keeps the last ones',
    () async {
      await SourceListCache(db).saveProjects('gl-acc', const [
        ProviderProject(
          id: '7',
          name: 'Wallet',
          accountId: 'gl-acc',
          programId: '3',
          programName: 'VN Program',
        ),
      ]);
      final adapter = await coordinator.adapterFor('gl-acc') as _MockAdapter;
      when(adapter.listProjects).thenAnswer(
        (_) async => const Ok([
          ProviderProject(
            id: '7',
            name: 'Wallet',
            accountId: 'gl-acc',
            programId: '3',
          ),
        ]),
      );

      final projects = (await coordinator.listProjects('gl-acc')).valueOrNull!;

      expect(projects.single.programName, 'VN Program');
    },
  );
}
