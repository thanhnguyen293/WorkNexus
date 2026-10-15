import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/zentao_ticket_form.dart';
import 'package:work_nexus/features/ticket_editor/data/datasources/ticket_draft_local_datasource.dart';
import 'package:work_nexus/features/ticket_editor/data/repositories/local_ticket_draft_repository.dart';
import 'package:work_nexus/features/ticket_editor/domain/entities/saved_ticket_draft.dart';

void main() {
  late AppDatabase db;
  late LocalTicketDraftRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = LocalTicketDraftRepository(TicketDraftLocalDatasource(db));
  });

  tearDown(() => db.close());

  final bug = SavedTicketDraft.bug(
    id: 'b1',
    accountId: 'zt',
    uid: 'u1',
    updatedAt: DateTime(2026, 10, 12, 9),
    draft: BugDraft(
      product: '4',
      project: '2',
      execution: '9',
      openedBuilds: const ['trunk', '12'],
      title: 'Crash on login',
      severity: 2,
      pri: 1,
      steps: '<p>Tap <b>Login</b></p>',
      os: const ['ios'],
      files: [
        TicketAttachment(
          id: '5',
          title: 'log.txt',
          url: 'https://zentao.example.com/file-5',
          addedDate: DateTime.utc(2026, 10, 2),
        ),
      ],
    ),
  );

  final task = SavedTicketDraft.task(
    id: 't1',
    accountId: 'zt',
    uid: 'u2',
    updatedAt: DateTime(2026, 10, 12, 10),
    draft: const TaskDraft(
      execution: '9',
      parent: '30',
      name: 'Wire up push',
      estimate: 1.5,
      desc: '<p>APNs</p>',
      mailto: ['an'],
    ),
  );

  test('a kept bug and task read back as they were written', () async {
    await repository.save(bug);
    await repository.save(task);

    expect((await repository.read('b1')).valueOrNull, bug);
    expect((await repository.read('t1')).valueOrNull, task);
  });

  test('drafts list the most recently changed first', () async {
    await repository.save(bug);
    await repository.save(task);

    final all = await repository.watchAll().first;
    expect(all.map((d) => d.id), ['t1', 'b1']);
  });

  test('added files are not kept', () async {
    final withFile = (bug as SavedBugDraft).copyWith(
      draft: bug.draft.copyWith(
        newFiles: [DraftFile(name: 'video.mp4', bytes: Uint8List(4))],
      ),
    );
    await repository.save(withFile);

    final read = (await repository.read('b1')).valueOrNull as SavedBugDraft?;
    expect(read?.draft.newFiles, isEmpty);
  });

  test('saving again replaces the draft; delete removes it', () async {
    await repository.save(bug);
    final renamed = (bug as SavedBugDraft).copyWith(
      draft: bug.draft.copyWith(title: 'Crash on logout'),
    );
    await repository.save(renamed);
    expect((await repository.read('b1')).valueOrNull?.title, 'Crash on logout');

    await repository.delete('b1');
    expect((await repository.read('b1')).valueOrNull, isNull);
  });

  test('v45 adds the drafts table to an existing database', () async {
    final dir = await Directory.systemTemp.createTemp('wn_drafts_mig');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/worknexus.db');
    final seed = AppDatabase(NativeDatabase(file));
    await seed.customStatement('SELECT 1');
    await seed.close();
    final raw = sqlite3.open(file.path);
    raw.execute('DROP TABLE ticket_drafts;');
    raw.execute('PRAGMA user_version = 44;');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    final repo = LocalTicketDraftRepository(
      TicketDraftLocalDatasource(upgraded),
    );
    await repo.save(task);
    expect((await repo.read('t1')).valueOrNull, task);
  });
}
