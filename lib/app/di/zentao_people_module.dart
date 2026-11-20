import 'package:injectable/injectable.dart';

import '../../core/database/database.dart';
import '../../core/domain/repositories/person_directory.dart';
import '../../core/platform/credential_store.dart';
import '../../shared/sync/data/sync_coordinator.dart';
import '../../tools/zentao/data/datasources/zentao_client.dart';
import '../../tools/zentao/data/repositories/zentao_person_directory.dart';

/// Wiring for chat's colleague lookup (department, contacts) over ZenTao,
/// kept out of the main composition root (`service_locator.dart`) so that
/// file stays within its size budget.
@module
abstract class ZenTaoPeopleModule {
  @lazySingleton
  PersonDirectory personDirectory(
    AppDatabase db,
    CredentialStore credentials,
    SyncCoordinator coordinator,
  ) => ZenTaoPersonDirectory(
    db,
    credentials,
    // The sync's pooled client, so people lookups share its ZenTao session:
    // ZenTao drops the previous session on every login.
    clientFactory: (account, password) =>
        switch (coordinator.buildAdapter(account, password)?.rawClient) {
          final ZenTaoClient pooled => pooled,
          _ => ZenTaoClient(
            baseUrl: account.baseUrl ?? '',
            account: account.handle,
            password: password,
          ),
        },
  );
}
