import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/presentation/widgets/mention_autocomplete.dart';

void main() {
  TextEditingValue typed(String text) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );

  test('finds the @query before the cursor, not inside words', () {
    final m = MentionAutocomplete()..update(typed('hi @Du'));
    expect(m.query, 'Du');
    m.update(typed('mail a@b'));
    expect(m.query, isNull);
  });

  test('insert replaces the query and remembers the mention', () {
    final m = MentionAutocomplete();
    final text = TextEditingController.fromValue(typed('ping @dy'));
    m.update(text.value);
    m.insert(text, (userId: 41, name: 'Dyno', account: 'dyno'));
    expect(text.text, 'ping @Dyno ');
    expect(m.mentions, {'Dyno': 41});
    expect(m.query, isNull);
  });

  test('Esc hides the list until another @ is typed', () {
    final m = MentionAutocomplete()..update(typed('@a'));
    m.dismiss();
    m.update(typed('@ab'));
    expect(m.query, isNull);
    m.update(typed('@ab @c'));
    expect(m.query, 'c');
  });

  test('filter puts prefix matches first, by name or account', () {
    final all = <MentionCandidate>[
      (userId: 1, name: 'Anh Long', account: 'long'),
      (userId: 2, name: 'Long Vu', account: 'vu'),
    ];
    expect(MentionAutocomplete.filter(all, 'long').map((c) => c.userId), [
      1,
      2,
    ]);
  });
}
