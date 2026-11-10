import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/tools/zentao/data/mappers/zentao_doc_history_mapper.dart';

void main() {
  test('entries read their date, who, the action and what changed', () {
    final history = mapZenTaoDocHistory({
      'actions': [
        {
          'id': 663973,
          'action': 'saveddraft',
          'hasRendered': true,
          'content':
              '2026-09-30 12:35:42, <strong>ViPham-VN-go</strong> save draft '
              '<strong></strong>.\n',
        },
        {
          'id': 664003,
          'action': 'edited',
          'content':
              '2026-09-30 12:56:37, edited by <strong>ViPham-VN-go</strong> .\n',
          'historyChanges':
              '<strong><i>Name</i></strong> is changed. The difference is \n'
              "<blockquote class='textdiff'>001- <del>Old</del><br />\n"
              '001+ <ins>New</ins></blockquote>\n'
              "<blockquote class='original'>001- <del>Old</del><br />\n"
              '001+ <ins>New</ins></blockquote>',
        },
        {'action': 'no id'},
      ],
    });

    expect(history, hasLength(2));
    final draft = history.first;
    expect(draft.id, '663973');
    expect(draft.action, 'saveddraft');
    expect(draft.date, DateTime(2026, 9, 30, 12, 35, 42));
    expect(draft.actor, 'ViPham-VN-go');
    expect(draft.summary, 'ViPham-VN-go save draft');
    expect(draft.changes, isEmpty);

    final edit = history.last;
    expect(edit.summary, 'edited by ViPham-VN-go');
    // The diff is read once (its `original` copy skipped).
    expect(edit.changes.single.field, 'Name');
    expect(edit.changes.single.removed, ['Old']);
    expect(edit.changes.single.added, ['New']);
  });

  test('no list is no history', () {
    expect(mapZenTaoDocHistory({'actions': 'x'}), isEmpty);
  });

  test(
    'a field reads its old and new value; the body only that it changed',
    () {
      final changes = parseZenTaoDocChanges(
        '<strong><i>Status</i></strong> is changed. It was "Draft" and it is '
        '"Released".<br />\n<strong><i>rawContent</i></strong> is changed. It '
        'was "" and it is "{"type":"page"}".<br />\n',
      );
      expect(changes, hasLength(2));
      expect(changes.first.field, 'Status');
      expect(changes.first.from, 'Draft');
      expect(changes.first.to, 'Released');
      expect(changes.last.isBody, isTrue);
      expect(changes.last.to, isNull, reason: 'no raw JSON kept');
    },
  );
}
