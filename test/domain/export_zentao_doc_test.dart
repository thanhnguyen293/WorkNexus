import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/tools/zentao/domain/entities/zentao_doc.dart';
import 'package:work_nexus/tools/zentao/domain/entities/zentao_doc_export_format.dart';
import 'package:work_nexus/tools/zentao/domain/repositories/zentao_doc_repository.dart';
import 'package:work_nexus/tools/zentao/domain/usecases/export_zentao_doc.dart';

class _MockRepository extends Mock implements ZenTaoDocRepository {}

const _account = Account(
  id: 'a1',
  workspaceId: 'w1',
  providerType: ProviderType.zentao,
  handle: 'thanh',
  baseUrl: 'https://zt.example.com',
);

const _doc = ZenTaoDoc(
  id: '50',
  title: 'Swap APIs',
  libId: '89',
  html: '<h2>Auth</h2><p><img src="/file-read-7.png"></p>',
);

void main() {
  late _MockRepository repository;
  late ExportZenTaoDoc export;

  setUp(() {
    repository = _MockRepository();
    export = ExportZenTaoDoc(repository);
    when(
      () => repository.saveText(any(), any()),
    ).thenAnswer((_) async => const Ok('/Downloads/x'));
  });

  String saved(String name) =>
      verify(() => repository.saveText(name, captureAny())).captured.single
          as String;

  test('Markdown is saved as <title>.md', () async {
    final res = await export(_account, _doc, ZenTaoDocExportFormat.markdown);
    expect(res, isA<Ok<String>>());
    expect(saved('Swap APIs.md'), startsWith('# Swap APIs\n\n## Auth'));
  });

  test('HTML is a standalone page whose site-relative links resolve', () async {
    await export(_account, _doc, ZenTaoDocExportFormat.html);
    final html = saved('Swap APIs.html');
    expect(html, contains('<title>Swap APIs</title>'));
    expect(html, contains('src="https://zt.example.com/file-read-7.png"'));
  });

  test('the backup is ZenTao\'s record, saved as <title>.json', () async {
    when(
      () => repository.readBackup('a1', '50'),
    ).thenAnswer((_) async => const Ok('{"id": 50}'));
    await export(_account, _doc, ZenTaoDocExportFormat.backup);
    expect(saved('Swap APIs.json'), '{"id": 50}');
  });

  test('a backup that cannot be read saves nothing', () async {
    when(
      () => repository.readBackup('a1', '50'),
    ).thenAnswer((_) async => const Err(NotFoundFailure('not cached')));
    final res = await export(_account, _doc, ZenTaoDocExportFormat.backup);
    expect(res, isA<Err<String>>());
    verifyNever(() => repository.saveText(any(), any()));
  });
}
