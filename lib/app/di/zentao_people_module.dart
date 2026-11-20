import 'package:injectable/injectable.dart';

import '../../core/database/database.dart';
import '../../core/domain/repositories/person_directory.dart';
import '../../core/platform/credential_store.dart';
import '../../shared/sync/data/sync_coordinator.dart';
import '../../tools/zentao/data/datasources/zentao_client.dart';
import '../../tools/zentao/data/repositories/local_zentao_profile_repository.dart';
import '../../tools/zentao/data/repositories/zentao_person_directory.dart';
import '../../tools/zentao/domain/repositories/zentao_profile_repository.dart';
import '../../tools/zentao/domain/usecases/refresh_zentao_profile.dart';
import '../../tools/zentao/domain/usecases/update_zentao_profile.dart';

/// Wiring for ZenTao people: the signed-in user's own profile and chat's
/// colleague lookup (department, contacts). Kept out of the main composition
/// root (`service_locator.dart`) so that file stays within its size budget.
@module
abstract class ZenTaoPeopleModule {
  @lazySingleton
  ZenTaoProfileRepository zenTaoProfileRepository(
    AppDatabase db,
    CredentialStore credentials,
    SyncCoordinator coordinator,
  ) => LocalZenTaoProfileRepository(
    db,
    credentials,
    clientFactory: _pooledClient(coordinator),
  );

  @lazySingleton
  RefreshZenTaoProfile refreshZenTaoProfile(
    ZenTaoProfileRepository repository,
  ) => RefreshZenTaoProfile(repository);

  @lazySingleton
  UpdateZenTaoProfile updateZenTaoProfile(ZenTaoProfileRepository repository) =>
      UpdateZenTaoProfile(repository);

  @lazySingleton
  PersonDirectory personDirectory(
    AppDatabase db,
    CredentialStore credentials,
    SyncCoordinator coordinator,
  ) => ZenTaoPersonDirectory(
    db,
    credentials,
    clientFactory: _pooledClient(coordinator),
  );
}

/// The sync's pooled ZenTao client, so profile and people lookups share its
/// session: ZenTao drops the previous session on every login.
ZenTaoProfileClientFactory _pooledClient(SyncCoordinator coordinator) =>
    (account, password) =>
        switch (coordinator.buildAdapter(account, password)?.rawClient) {
          final ZenTaoClient pooled => pooled,
          _ => ZenTaoClient(
            baseUrl: account.baseUrl ?? '',
            account: account.handle,
            password: password,
          ),
        };
