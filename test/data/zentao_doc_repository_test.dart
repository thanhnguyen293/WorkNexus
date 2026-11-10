import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/tools/zentao/data/datasources/zentao_docs_remote.dart';
import 'package:work_nexus/tools/zentao/data/repositories/local_zentao_doc_repository.dart';
import 'package:work_nexus/tools/zentao/domain/entities/zentao_doc_lib.dart';
import 'package:work_nexus/tools/zentao/domain/entities/zentao_doc_pins.dart';
import 'package:work_nexus/tools/zentao/domain/entities/zentao_doc_summary.dart';

class _MockRemote extends Mock implements ZenTaoDocsRemote {}

const _account = Account(
  id: 'a1',
  workspaceId: 'w1',
  providerType: ProviderType.zentao,
  handle: 'thanh',
  baseUrl: 'https://zt.example/zentao',
  credentialsRef: 'ref',
);

Map<String, dynamic> _doc(String id, {String content = '<p>Hi</p>'}) => {
  'id': int.parse(id),
  'title': 'Doc $id',
  'lib': 247,
  'type': 'text',
  'content': content,
};

void main() {
  late AppDatabase db;
  late _MockRemote remote;
  late LocalZenTaoDocRepository repository;
  late Directory downloads;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    remote = _MockRemote();
    when(() => remote.baseUrl).thenReturn('https://zt.example/zentao');
    downloads = await Directory.systemTemp.createTemp('zentao_docs_test');
    repository = LocalZenTaoDocRepository(
      db,
      (_) async => remote,
      downloads: () async => downloads,
    );
  });

  tearDown(() async {
    await db.close();
    await downloads.delete(recursive: true);
  });

  test('refreshLibs stores the libraries the stream then emits', () async {
    when(() => remote.libs()).thenAnswer(
      (_) async => {
        'libs': [
          {'id': 247, 'name': 'Notification'},
        ],
      },
    );

    expect(await repository.refreshLibs(_account), isA<Ok<void>>());

    final libs = await repository.watchLibs('a1').first;
    expect(libs.single.name, 'Notification');
    expect(await repository.watchLibs('other').first, isEmpty);
  });

  test('refreshDocs keeps each library apart', () async {
    when(() => remote.docs('247')).thenAnswer(
      (_) async => {
        'docs': [
          {'id': 115, 'title': 'Payloads'},
        ],
      },
    );
    when(() => remote.docs('248')).thenAnswer((_) async => {'docs': []});

    await repository.refreshDocs(_account, '247');
    await repository.refreshDocs(_account, '248');

    expect((await repository.watchDocs('a1', '247').first).single.id, '115');
    expect(await repository.watchDocs('a1', '248').first, isEmpty);
  });

  test('an unreadable document keeps the cached copy', () async {
    when(() => remote.doc('111')).thenAnswer((_) async => _doc('111'));
    await repository.refreshDoc(_account, '111');

    when(() => remote.doc('111')).thenAnswer((_) async => {'error': 'denied'});
    final res = await repository.refreshDoc(_account, '111');

    expect(res.failureOrNull, isA<NotFoundFailure>());
    final doc = await repository.watchDoc('a1', '111').first;
    expect(doc?.html, '<p>Hi</p>');
  });

  test('a 403 from the server is a not-found failure', () async {
    final options = RequestOptions(path: '/docs/9');
    when(() => remote.doc('9')).thenThrow(
      DioException.badResponse(
        statusCode: 403,
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 403),
      ),
    );

    final res = await repository.refreshDoc(_account, '9');

    expect(res.failureOrNull, isA<NotFoundFailure>());
    expect(await repository.watchDoc('a1', '9').first, isNull);
  });

  test('no credentials is an auth failure', () async {
    final repo = LocalZenTaoDocRepository(db, (_) async => null);
    expect(
      (await repo.refreshLibs(_account)).failureOrNull,
      isA<AuthFailure>(),
    );
  });

  test('saveFile writes to Downloads without overwriting', () async {
    when(
      () => remote.download(any()),
    ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
    const file = TicketAttachment(
      id: '1',
      title: 'notes.md',
      url: 'https://zt.example/zentao/file-download-1.md',
    );

    final first = await repository.saveFile(_account, file);
    final second = await repository.saveFile(_account, file);

    expect(first.valueOrNull, endsWith('notes.md'));
    expect(second.valueOrNull, endsWith('notes (2).md'));
    expect(await File(second.valueOrNull!).readAsBytes(), [1, 2, 3]);
  });

  test('pins are stored per account and read back', () async {
    const pins = ZenTaoDocPins(
      libs: [ZenTaoDocLib(id: '1', name: 'A <B>')],
      docs: [ZenTaoDocSummary(id: '9', title: 'Post & More', libId: '1')],
    );

    expect(await repository.savePins('a1', pins), isA<Ok<void>>());

    expect(await repository.watchPins('a1').first, pins);
    expect(await repository.watchPins('a2').first, const ZenTaoDocPins());
  });

  test('refreshHistory stores the document history', () async {
    when(() => remote.history('111')).thenAnswer(
      (_) async => {
        'actions': [
          {
            'id': 1,
            'action': 'edited',
            'content': '2026-10-29 11:25:30, edited by <strong>Vi</strong> .',
          },
        ],
      },
    );

    expect(await repository.refreshHistory(_account, '111'), isA<Ok<void>>());

    final history = await repository.watchHistory('a1', '111').first;
    expect(history.single.actor, 'Vi');
    expect(await repository.watchHistory('a1', '222').first, isEmpty);
  });
}
