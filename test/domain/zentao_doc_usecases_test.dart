import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/tools/zentao/domain/entities/zentao_doc_lib.dart';
import 'package:work_nexus/tools/zentao/domain/entities/zentao_doc_pins.dart';
import 'package:work_nexus/tools/zentao/domain/entities/zentao_doc_summary.dart';
import 'package:work_nexus/tools/zentao/domain/repositories/zentao_doc_repository.dart';
import 'package:work_nexus/tools/zentao/domain/usecases/filter_zentao_doc_libs.dart';
import 'package:work_nexus/tools/zentao/domain/usecases/refresh_zentao_doc.dart';
import 'package:work_nexus/tools/zentao/domain/usecases/refresh_zentao_doc_libs.dart';
import 'package:work_nexus/tools/zentao/domain/usecases/refresh_zentao_docs.dart';
import 'package:work_nexus/tools/zentao/domain/usecases/toggle_zentao_doc_pin.dart';

class _MockRepository extends Mock implements ZenTaoDocRepository {}

const _account = Account(
  id: 'a1',
  workspaceId: 'w1',
  providerType: ProviderType.zentao,
  handle: 'thanh',
);

void main() {
  late _MockRepository repository;

  setUpAll(() => registerFallbackValue(_account));
  setUp(() => repository = _MockRepository());

  group('FilterZenTaoDocLibs', () {
    const libs = [
      ZenTaoDocLib(id: '1', name: 'Notification'),
      ZenTaoDocLib(id: '2', name: 'Payment API'),
      ZenTaoDocLib(id: '3', name: 'notes'),
    ];
    const filter = FilterZenTaoDocLibs();

    test('an empty query keeps every library', () {
      expect(filter(libs, '  '), libs);
    });

    test('matches the name case-insensitively, in order', () {
      expect(filter(libs, ' NOT ').map((l) => l.id), ['1', '3']);
    });
  });

  test('RefreshZenTaoDocLibs refreshes the account libraries', () async {
    when(
      () => repository.refreshLibs(any()),
    ).thenAnswer((_) async => const Ok(null));
    final res = await RefreshZenTaoDocLibs(repository)(_account);
    expect(res.isOk, isTrue);
    verify(() => repository.refreshLibs(_account)).called(1);
  });

  test('RefreshZenTaoDocs refreshes one library', () async {
    when(
      () => repository.refreshDocs(any(), any()),
    ).thenAnswer((_) async => const Err(NetworkFailure('offline')));
    final res = await RefreshZenTaoDocs(repository)(_account, '247');
    expect(res.failureOrNull, isA<NetworkFailure>());
    verify(() => repository.refreshDocs(_account, '247')).called(1);
  });

  test('RefreshZenTaoDoc refreshes one document', () async {
    when(
      () => repository.refreshDoc(any(), any()),
    ).thenAnswer((_) async => const Ok(null));
    await RefreshZenTaoDoc(repository)(_account, '111');
    verify(() => repository.refreshDoc(_account, '111')).called(1);
  });

  group('ToggleZenTaoDocPin', () {
    const lib = ZenTaoDocLib(id: '247', name: 'Notification');
    const doc = ZenTaoDocSummary(id: '115', title: 'Payloads', libId: '247');

    setUp(() {
      registerFallbackValue(const ZenTaoDocPins());
      when(
        () => repository.savePins(any(), any()),
      ).thenAnswer((_) async => const Ok(null));
    });

    test('pins a library not pinned yet, after the others', () async {
      const other = ZenTaoDocLib(id: '1', name: 'Other');
      when(
        () => repository.watchPins('a1'),
      ).thenAnswer((_) => Stream.value(const ZenTaoDocPins(libs: [other])));

      await ToggleZenTaoDocPin(repository)('a1', lib: lib);

      verify(
        () =>
            repository.savePins('a1', const ZenTaoDocPins(libs: [other, lib])),
      ).called(1);
    });

    test('unpins a pinned document', () async {
      when(
        () => repository.watchPins('a1'),
      ).thenAnswer((_) => Stream.value(const ZenTaoDocPins(docs: [doc])));

      await ToggleZenTaoDocPin(repository)('a1', doc: doc);

      verify(() => repository.savePins('a1', const ZenTaoDocPins())).called(1);
    });
  });
}
