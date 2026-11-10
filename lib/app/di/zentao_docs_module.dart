import 'package:injectable/injectable.dart';

import '../../core/database/database.dart';
import '../../core/platform/credential_store.dart';
import '../../shared/sync/data/sync_coordinator.dart';
import '../../tools/zentao/data/datasources/zentao_client.dart';
import '../../tools/zentao/data/datasources/zentao_docs_remote.dart';
import '../../tools/zentao/data/repositories/local_zentao_doc_repository.dart';
import '../../tools/zentao/domain/repositories/zentao_doc_repository.dart';
import '../../tools/zentao/domain/usecases/refresh_zentao_doc.dart';
import '../../tools/zentao/domain/usecases/refresh_zentao_doc_history.dart';
import '../../tools/zentao/domain/usecases/refresh_zentao_doc_libs.dart';
import '../../tools/zentao/domain/usecases/refresh_zentao_docs.dart';
import '../../tools/zentao/domain/usecases/toggle_zentao_doc_pin.dart';

/// Wiring for ZenTao's Docs place, kept out of the main composition root
/// (`service_locator.dart`) so that file stays within its size budget.
@module
abstract class ZenTaoDocsModule {
  @lazySingleton
  ZenTaoDocRepository zenTaoDocRepository(
    AppDatabase db,
    CredentialStore credentials,
    SyncCoordinator coordinator,
  ) => LocalZenTaoDocRepository(db, (account) async {
    final ref = account.credentialsRef;
    if (ref == null || (account.baseUrl ?? '').isEmpty) return null;
    final password = await credentials.read(ref);
    if (password == null || password.isEmpty) return null;
    // The sync's pooled client, so documents share its ZenTao session.
    final client = switch (coordinator
        .buildAdapter(account, password)
        ?.rawClient) {
      final ZenTaoClient pooled => pooled,
      _ => ZenTaoClient(
        baseUrl: account.baseUrl ?? '',
        account: account.handle,
        password: password,
      ),
    };
    return ZenTaoDocsRemote(client);
  });

  @lazySingleton
  RefreshZenTaoDocLibs refreshZenTaoDocLibs(ZenTaoDocRepository repository) =>
      RefreshZenTaoDocLibs(repository);

  @lazySingleton
  RefreshZenTaoDocs refreshZenTaoDocs(ZenTaoDocRepository repository) =>
      RefreshZenTaoDocs(repository);

  @lazySingleton
  RefreshZenTaoDoc refreshZenTaoDoc(ZenTaoDocRepository repository) =>
      RefreshZenTaoDoc(repository);

  @lazySingleton
  ToggleZenTaoDocPin toggleZenTaoDocPin(ZenTaoDocRepository repository) =>
      ToggleZenTaoDocPin(repository);

  @lazySingleton
  RefreshZenTaoDocHistory refreshZenTaoDocHistory(
    ZenTaoDocRepository repository,
  ) => RefreshZenTaoDocHistory(repository);
}
