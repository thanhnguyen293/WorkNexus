import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/features/connections/data/zentao/zentao_models.dart';
import 'package:work_nexus/features/connections/data/zentao/zentao_normalize.dart';

void main() {
  group('status mapping', () {
    test('bug: active depends on confirmed', () {
      expect(
        mapZenTaoStatus(ZenTaoType.bug, 'active', confirmed: 0),
        UnifiedStatus.inbox,
      );
      expect(
        mapZenTaoStatus(ZenTaoType.bug, 'active', confirmed: 1),
        UnifiedStatus.todo,
      );
      expect(mapZenTaoStatus(ZenTaoType.bug, 'resolved'), UnifiedStatus.review);
      expect(mapZenTaoStatus(ZenTaoType.bug, 'closed'), UnifiedStatus.done);
    });
    test('task states', () {
      expect(mapZenTaoStatus(ZenTaoType.task, 'wait'), UnifiedStatus.todo);
      expect(
        mapZenTaoStatus(ZenTaoType.task, 'doing'),
        UnifiedStatus.inprogress,
      );
      expect(mapZenTaoStatus(ZenTaoType.task, 'pause'), UnifiedStatus.blocked);
      expect(mapZenTaoStatus(ZenTaoType.task, 'done'), UnifiedStatus.review);
      expect(mapZenTaoStatus(ZenTaoType.task, 'closed'), UnifiedStatus.done);
    });
    test('story states', () {
      expect(mapZenTaoStatus(ZenTaoType.story, 'draft'), UnifiedStatus.inbox);
      expect(
        mapZenTaoStatus(ZenTaoType.story, 'reviewing'),
        UnifiedStatus.review,
      );
      expect(mapZenTaoStatus(ZenTaoType.story, 'active'), UnifiedStatus.todo);
    });
  });

  group('priority mapping', () {
    test('pri 1..4 maps urgent..low; 0/null → medium', () {
      expect(mapZenTaoPriority(1), Priority.urgent);
      expect(mapZenTaoPriority(2), Priority.high);
      expect(mapZenTaoPriority(3), Priority.medium);
      expect(mapZenTaoPriority(4), Priority.low);
      expect(mapZenTaoPriority(0), Priority.medium);
      expect(mapZenTaoPriority(null), Priority.medium);
    });
  });

  test('normalizes a REST v1 bug payload', () {
    final json = <String, dynamic>{
      'id': 1092,
      'title': 'Inventory sync fails for warehouse #3',
      'steps': '<p>The sync aborts on a <b>duplicate SKU</b>.</p>',
      'status': 'active',
      'resolution': 'postponed',
      'confirmed': 1,
      'pri': 1,
      'severity': 2,
      'keywords': 'sync,inventory',
      'product': 'Internal ERP',
      'assignedTo': {'account': 'mobile2', 'realname': 'Thanh Nguyen'},
      'openedBy': {'account': 'tester', 'realname': 'QA One'},
      'openedBuild': 'trunk',
      'assignedDate': '2026-07-16T10:00:00Z',
      'resolvedBy': {'account': 'dev', 'realname': 'Dev One'},
      'resolvedDate': '2026-07-17T09:00:00Z',
      'resolvedBuild': '2026.07',
      'closedBy': {'account': 'qa', 'realname': 'QA Close'},
      'closedDate': '2026-07-18T09:00:00Z',
      'deadline': '2026-07-20',
      'type': 'codeerror',
      'os': 'iOS',
      'browser': 'Safari',
      'openedDate': '2026-07-15T09:00:00Z',
      'lastEditedDate': '2026-07-17 08:30:00',
      'projectName': 'Mobile App',
      'executionName': 'Sprint 24',
      'storyTitle': 'Translate social post',
      'taskName': 'Fix mention parser',
      'planName': 'July release',
    };
    final t = normalizeZenTao(
      ZenTaoEntity.fromJson(json),
      type: ZenTaoType.bug,
      accountId: 'ztB',
      baseUrl: 'https://zentao.example.com/',
    );

    expect(t.id, 'ztB:1092');
    expect(t.providerType, ProviderType.zentao);
    expect(t.externalType, 'Bug');
    expect(t.status, UnifiedStatus.todo); // active + confirmed=1
    expect(t.priority, Priority.urgent); // pri 1
    expect(t.severity, 2);
    expect(t.body, contains('duplicate SKU')); // html stripped
    expect(t.body, isNot(contains('<b>')));
    expect(t.assignee, 'Thanh Nguyen');
    expect(t.labels, containsAll(<String>['sync', 'inventory']));
    expect(t.labels, contains('resolution:postponed'));
    expect(t.url, 'https://zentao.example.com/bug-view-1092.html');
    expect(t.createdAt, isNotNull);
    expect(t.updatedAt, isNotNull);
    final entity = t.providerEntity;
    expect(entity, isA<ZenTaoBugEntity>());
    final bug = entity as ZenTaoBugEntity;
    expect(bug.confirmed, 1);
    expect(bug.resolution, 'postponed');
    expect(bug.openedBy, 'QA One');
    expect(bug.openedBuild, 'trunk');
    expect(bug.assignedDate, DateTime.parse('2026-07-16T10:00:00Z'));
    expect(bug.resolvedBy, 'Dev One');
    expect(bug.resolvedBuild, '2026.07');
    expect(bug.closedBy, 'QA Close');
    expect(bug.deadline, '2026-07-20');
    expect(bug.bugType, 'codeerror');
    expect(bug.os, 'iOS');
    expect(bug.browser, 'Safari');
    expect(bug.projectName, 'Mobile App');
    expect(bug.executionName, 'Sprint 24');
    expect(bug.storyTitle, 'Translate social post');
    expect(bug.taskName, 'Fix mention parser');
    expect(bug.planName, 'July release');
  });

  test('handles the 0000-00-00 date sentinel and bare-string assignee', () {
    final json = <String, dynamic>{
      'id': 5,
      'name': 'A task',
      'status': 'doing',
      'pri': 2,
      'assignedTo': 'mobile2',
      'openedDate': '0000-00-00 00:00:00',
    };
    final t = normalizeZenTao(
      ZenTaoEntity.fromJson(json),
      type: ZenTaoType.task,
      accountId: 'ztB',
      baseUrl: 'https://z',
    );
    expect(t.createdAt, isNull);
    expect(t.assignee, 'mobile2');
    expect(t.status, UnifiedStatus.inprogress);
  });

  test('html <img> keeps its absolute URL (no double-prefix)', () {
    const html =
        '<p>x</p><img src="https://z.example.com/zentao/file-read-18796.png" '
        'width="505" alt="shot.png" />';
    final md = htmlToMarkdown(html);
    expect(md, contains('(https://z.example.com/zentao/file-read-18796.png)'));
    expect(md, isNot(contains('zentao/https://'))); // not mangled
  });

  group('activity descriptions', () {
    test('created / assigned / resolved / closed / edited', () {
      expect(
        zentaoActionText(ZenTaoAction.fromJson({'action': 'opened'})),
        'created',
      );
      expect(
        zentaoActionText(
          ZenTaoAction.fromJson({'action': 'assigned', 'extra': 'thanh'}),
        ),
        'assigned to thanh',
      );
      expect(
        zentaoActionText(
          ZenTaoAction.fromJson({'action': 'resolved', 'extra': 'notrepro'}),
        ),
        'resolved · resolution: Irreproducible',
      );
      expect(
        zentaoActionText(
          ZenTaoAction.fromJson({'action': 'resolved', 'extra': 'fixed'}),
        ),
        'resolved · resolution: Fixed',
      );
      expect(
        zentaoActionText(ZenTaoAction.fromJson({'action': 'closed'})),
        'closed',
      );
      expect(
        zentaoActionText(ZenTaoAction.fromJson({'action': 'edited'})),
        'edited',
      );
    });

    test('assigned target can be an account object (realname)', () {
      expect(
        zentaoActionText(
          ZenTaoAction.fromJson({
            'action': 'assigned',
            'extra': {'account': 'thanh', 'realname': 'Thanh-VN-Flutter'},
          }),
        ),
        'assigned to Thanh-VN-Flutter',
      );
    });
  });

  group('attachments', () {
    test('maps the id-keyed files map onto sorted TicketAttachments', () {
      final json = <String, dynamic>{
        'id': 2668,
        'title': 'A bug',
        'status': 'active',
        'activatedCount': 2,
        'files': {
          '11548': {
            'id': 11548,
            'title': 'bandicam.mp4',
            'extension': 'mp4',
            'size': 5003944,
            'addedBy': 'Ryan',
            'addedDate': '2026-05-21 00:00:00',
            'url': 'https://z.example.com/zentao/file-download-11548.json',
          },
          '7931': {
            'id': 7931,
            'title': 'ScreenRecording.MP4',
            'extension': 'mp4',
            'size': 39124123,
            'addedBy': 'Ryan',
          },
        },
      };
      final t = normalizeZenTao(
        ZenTaoEntity.fromJson(json),
        type: ZenTaoType.bug,
        accountId: 'ztB',
        baseUrl: 'https://z.example.com/',
      );
      final bug = t.providerEntity! as ZenTaoBugEntity;
      expect(bug.activatedCount, 2);
      expect(bug.attachments, hasLength(2));
      // Ordered by ascending id (upload order), not map order.
      expect(bug.attachments.first.id, '7931');
      expect(bug.attachments.first.size, 39124123);
      // Missing url falls back to a constructed file-download path.
      expect(
        bug.attachments.first.url,
        'https://z.example.com/file-download-7931.mp4',
      );
      // Present url is preserved verbatim.
      expect(
        bug.attachments.last.url,
        'https://z.example.com/zentao/file-download-11548.json',
      );
      expect(bug.attachments.last.addedDate, isNotNull);
    });

    test('no files → empty attachments, null activatedCount', () {
      final t = normalizeZenTao(
        ZenTaoEntity.fromJson({'id': 1, 'title': 'x', 'status': 'active'}),
        type: ZenTaoType.bug,
        accountId: 'z',
        baseUrl: 'https://z',
      );
      final bug = t.providerEntity! as ZenTaoBugEntity;
      expect(bug.attachments, isEmpty);
      expect(bug.activatedCount, isNull);
    });
  });

  group('action attachments', () {
    test('splits "Added Files <name>" prefix from the note', () {
      final parsed = zentaoActionAttachments(
        'Added Files 10.mp4\r\n<p>Please recheck on the latest build</p>',
      );
      expect(parsed.files, ['10.mp4']);
      expect(parsed.note, 'Please recheck on the latest build');
    });

    test('a plain comment yields no files and the stripped note', () {
      final parsed = zentaoActionAttachments('<p>Reopening this ticket.</p>');
      expect(parsed.files, isEmpty);
      expect(parsed.note, 'Reopening this ticket.');
    });
  });
}
