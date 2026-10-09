import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/zentao_ticket_form.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/features/connections/data/zentao/zentao_client.dart';
import 'package:work_nexus/features/connections/data/zentao/zentao_form_parsing.dart';
import 'package:work_nexus/features/connections/data/zentao/zentao_ticket_forms.dart';

class _Fake implements HttpClientAdapter {
  _Fake(this.handler);
  final Object Function(RequestOptions) handler;
  final requests = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(handler(options)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

/// A classic page: ZenTao double-encodes its `data`.
Map<String, Object> _page(Map<String, Object?> data) => {
  'status': 'success',
  'data': jsonEncode(data),
};

(ZenTaoTicketForms, _Fake) _forms(Object Function(RequestOptions) handler) {
  final fake = _Fake((o) {
    if (o.path.endsWith('/tokens')) return {'token': 't'};
    return handler(o);
  });
  final client = ZenTaoClient(
    baseUrl: 'https://z.example.com/zentao',
    account: 'me',
    password: 'pw',
    dio: Dio()..httpClientAdapter = fake,
  );
  return (ZenTaoTicketForms(client), fake);
}

Map<String, dynamic> _sent(_Fake fake, String path) =>
    Map.from(fake.requests.lastWhere((r) => r.path.contains(path)).data as Map);

void main() {
  group('parsing', () {
    test('options read maps and PHP lists, leaving out the "none"s', () {
      expect(zentaoOptions({'0': '/', '3': '/Login', '': ''}), const [
        FormOption(value: '3', label: '/Login'),
      ]);
      expect(zentaoOptions(['', 'Trunk']), const [
        FormOption(value: '1', label: 'Trunk'),
      ]);
    });

    test('a save reply gives the id, or the refused fields', () {
      expect(zentaoSaveResult({'result': 'success', 'id': 42}), '42');
      // 18.x wraps an edit's reply like a page.
      expect(
        zentaoSaveResult(_page({'locate': 'https://z/zentao/bug-view-7.html'})),
        '7',
      );
      expect(
        () => zentaoSaveResult({
          'result': 'fail',
          'message': {
            'openedBuild[]': ['『Affected Build』should not be blank.'],
          },
        }),
        throwsA(
          isA<ValidationFailure>().having((f) => f.fields, 'fields', {
            'openedBuild': '『Affected Build』should not be blank.',
          }),
        ),
      );
      expect(
        () => zentaoSaveResult('<html>SQL error</html>'),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  test('a new bug on 18.x reads its flat defaults and choices', () async {
    final (forms, _) = _forms(
      (_) => _page({
        'bugTitle': '',
        'products': {'4': 'VN_Socialfi'},
        'moduleOptionMenu': {'0': '/', '12': '/Feed'},
        'builds': {'trunk': 'Trunk'},
        'productMembers': {'thanh': 'Thanh', 'closed': 'Closed'},
        'steps': '&lt;p&gt;[Steps]&lt;/p&gt;',
        'severity': '2',
        'type': 'codeerror',
      }),
    );

    final form = await forms.newBug('4');

    expect(form.draft.severity, 2);
    expect(form.draft.steps, '<p>[Steps]</p>');
    expect(form.draft.openedBuilds, ['trunk']);
    expect(form.options.modules.single.label, '/Feed');
    expect(form.options.users, const [
      FormOption(value: 'thanh', label: 'Thanh'),
    ]);
  });

  test('editing a resolved bug on 18.x sends every field back', () async {
    final (forms, fake) = _forms((o) {
      if (o.path.contains('bug-edit-7') && o.method == 'GET') {
        return _page({
          'bug': {
            'id': 7,
            'product': 4,
            'title': 'A &amp; B',
            'openedBuild': 'trunk,12',
            'os': 'android,ios',
            'status': 'resolved',
            'resolution': 'fixed',
            'resolvedBuild': 'trunk',
            'linkBug': '3,5',
            'lastEditedDate': '2026-09-01 10:00:00',
            'deadline': '0000-00-00',
          },
          'products': {'4': 'VN_Socialfi'},
        });
      }
      if (o.path.contains('bug-create-4')) {
        return _page({
          'builds': {'trunk': 'Trunk', '12': 'v1.2'},
        });
      }
      return {
        'status': 'success',
        'data': jsonEncode({'locate': 'x'}),
      };
    });

    final form = await forms.editBug('7');
    expect(form.draft.title, 'A & B');
    expect(form.draft.openedBuilds, ['trunk', '12']);
    expect(form.options.builds, hasLength(2));

    final id = await forms.saveBug(
      form,
      form.draft.copyWith(title: 'A & C'),
      'u1',
    );

    expect(id, '7');
    final sent = _sent(fake, 'bug-edit-7');
    expect(sent['title'], 'A & C');
    expect(sent['os[]'], ['android', 'ios']);
    expect(sent['status'], 'resolved');
    expect(sent['resolution'], 'fixed');
    expect(sent['lastEditedDate'], '2026-09-01 10:00:00');
    // 18.x names related bugs linkBug, and an empty date is left out.
    expect(sent['linkBug[]'], ['3', '5']);
    expect(sent.containsKey('relatedBug[]'), isFalse);
    expect(sent.containsKey('deadline'), isFalse);
  });

  test('a new task on 18.x sends its assignee as a list', () async {
    final (forms, fake) = _forms((o) {
      if (o.method == 'GET') {
        return _page({
          'moduleOptionMenu': {'0': '/'},
          'members': {'thanh': 'Thanh'},
          'task': {'type': 'devel'},
        });
      }
      return {'result': 'success', 'id': 99};
    });
    final form = await forms.newTask('9');

    final id = await forms.saveTask(
      form,
      form.draft.copyWith(name: 'mobile', assignedTo: 'thanh', estimate: 4),
      'u2',
    );

    expect(id, '99');
    final sent = _sent(fake, 'task-create-9');
    expect(sent['assignedTo[]'], ['thanh']);
    expect(sent['estimate'], '4');
    expect(sent.containsKey('keywords'), isFalse);
  });

  test('an uploaded image is embedded at its absolute URL', () async {
    final (forms, fake) = _forms(
      (_) => {'error': 0, 'url': '/zentao/file-read-31.png'},
    );

    final url = await forms.uploadImage(
      'u3',
      Uint8List.fromList([1, 2, 3]),
      'shot.png',
    );

    expect(url, 'https://z.example.com/zentao/file-read-31.png');
    expect(fake.requests.last.path, contains('file-ajaxUpload-u3'));
  });
}
