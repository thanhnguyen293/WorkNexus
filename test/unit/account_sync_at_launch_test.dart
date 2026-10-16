import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/app/shell/account_sync_at_launch.dart';
import 'package:work_nexus/core/data/repositories/settings_sync_status_repository.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter_registry.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/value_objects/account_sync_status.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/platform/credential_store.dart';
import 'package:work_nexus/shared/sync/data/sync_coordinator.dart';

class _MemoryCredentialStore extends CredentialStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String ref) async => values[ref];

  @override
  Future<void> write(String ref, String secret) async => values[ref] = secret;
}

class _MockAdapter extends Mock implements ProviderAdapter {}

/// Builds one adapter per account and counts the assigned-items fetches.
class _Registry implements ProviderAdapterRegistry {
  final fetches = <String, int>{};

  @override
  ProviderAdapter? createAdapter(
    Account account,
    String secret, {
    dynamic zenClient,
  }) {
    final adapter = _MockAdapter();
    when(adapter.listAssignedTickets).thenAnswer((_) async {
      fetches.update(account.id, (n) => n + 1, ifAbsent: () => 1);
      return const Ok(TicketPage(tickets: []));
    });
    return adapter;
  }
}

Account _account(String id, ProviderType type, {bool signedIn = true}) =>
    Account(
      id: id,
      workspaceId: 'w',
      providerType: type,
      handle: 'me',
      credentialsRef: signedIn ? 'secret:$id' : null,
    );

void main() {
  test('launch syncs each signed-in account once and records when', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final status = SettingsSyncStatusRepository(db);
    addTearDown(status.dispose);
    final credentials = _MemoryCredentialStore()
      ..values.addAll({
        'secret:zt': 'pw',
        'secret:gl': 'token',
        'secret:gh': 'token',
      });
    final registry = _Registry();
    final coordinator = SyncCoordinator(
      db,
      credentials,
      registry: registry,
      statusRepository: status,
    );
    final accounts = [
      _account('zt', ProviderType.zentao),
      _account('gl', ProviderType.gitlab),
      _account('gh', ProviderType.github),
      _account('off', ProviderType.zentao, signedIn: false),
    ];
    final container = ProviderContainer(
      overrides: [
        accountsProvider.overrideWith((ref) => Stream.value(accounts)),
        accountSyncServiceProvider.overrideWithValue(coordinator),
      ],
    );
    addTearDown(container.dispose);

    container.listen(launchAccountSyncProvider, (_, _) {});
    await pumpEventQueue();
    // A later emission (an account edited) syncs nothing again.
    container.invalidate(accountsProvider);
    await pumpEventQueue();

    expect(registry.fetches, {'zt': 1, 'gl': 1, 'gh': 1});
    for (final id in ['zt', 'gl', 'gh']) {
      final now = await status.getStatus(id);
      expect(now, isA<SyncIdle>(), reason: id);
      expect((now as SyncIdle).lastSyncedAt, isNotNull, reason: id);
    }
  });
}
