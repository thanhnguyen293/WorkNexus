import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/app/di/service_locator.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/tools/zentao/domain/repositories/zentao_doc_repository.dart';
import 'package:work_nexus/tools/zentao/domain/usecases/refresh_zentao_doc_libs.dart';
import 'package:work_nexus/tools/zentao/presentation/providers/zentao_doc_providers.dart';

class _MockRepository extends Mock implements ZenTaoDocRepository {}

const _account = Account(
  id: 'a1',
  workspaceId: 'w1',
  providerType: ProviderType.zentao,
  handle: 'thanh',
);

void main() {
  late _MockRepository repository;
  const key = (account: _account, libId: null, docId: null);

  setUpAll(() => registerFallbackValue(_account));
  setUp(() async {
    await getIt.reset();
    repository = _MockRepository();
    when(
      () => repository.refreshLibs(any()),
    ).thenAnswer((_) async => const Ok(null));
    getIt.registerSingleton(RefreshZenTaoDocLibs(repository));
  });
  tearDown(getIt.reset);

  // testWidgets for its fake clock: the idle timer runs on it.
  testWidgets(
    'leaving Docs briefly does not fetch again; a long absence does',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      var sub = container.listen(zentaoDocSyncProvider(key), (_, _) {});
      await tester.pump();
      sub.close(); // the pane goes away (a trip to Bugs)
      await tester.pump(const Duration(minutes: 1));

      sub = container.listen(zentaoDocSyncProvider(key), (_, _) {});
      await tester.pump();
      verify(() => repository.refreshLibs(_account)).called(1);

      sub.close();
      await tester.pump(ZenTaoDocSync.idleLife + const Duration(seconds: 1));
      container.listen(zentaoDocSyncProvider(key), (_, _) {});
      await tester.pump();
      verify(() => repository.refreshLibs(_account)).called(1);
    },
  );
}
