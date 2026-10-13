import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_mention_text_controller.dart';

void main() {
  late ChatMentionTextController c;

  /// "hi @Dyno " with the mention of user 41 at 3–8.
  setUp(() {
    c = ChatMentionTextController()..replaceSelection('hi @d');
    c.insertMention(3, 5, id: 41, name: 'Dyno');
  });
  tearDown(() => c.dispose());

  void type(String text, int at) => c.value = TextEditingValue(
    text: c.text.replaceRange(at, at, text),
    selection: TextSelection.collapsed(offset: at + text.length),
  );

  void backspace(int at) => c.value = TextEditingValue(
    text: c.text.replaceRange(at - 1, at, ''),
    selection: TextSelection.collapsed(offset: at - 1),
  );

  test('a mention is inserted with a space, the caret after it', () {
    expect(c.text, 'hi @Dyno ');
    expect(c.mentions, [(start: 3, end: 8, id: 41)]);
    expect(c.selection, const TextSelection.collapsed(offset: 9));
  });

  test('typing before a mention moves it', () {
    type('oh ', 0);
    expect(c.mentions, [(start: 6, end: 11, id: 41)]);
  });

  test('typing right after a mention leaves it whole', () {
    type('o', 8);
    expect(c.text, 'hi @Dynoo ');
    expect(c.mentions, [(start: 3, end: 8, id: 41)]);
  });

  test('typing inside a mention makes it plain text', () {
    // The same letter as the one after it: the caret tells where it went.
    type('n', 6);
    expect(c.text, 'hi @Dynno ');
    expect(c.mentions, isEmpty);
  });

  test('Backspace into a mention deletes it whole', () {
    backspace(8);
    expect(c.text, 'hi  ');
    expect(c.mentions, isEmpty);
    expect(c.selection, const TextSelection.collapsed(offset: 3));
  });

  test('an IME composing over a mention is left as it is', () {
    c.value = const TextEditingValue(
      text: 'hi @Dyn ',
      selection: TextSelection.collapsed(offset: 7),
      composing: TextRange(start: 4, end: 7),
    );
    expect(c.text, 'hi @Dyn ');
    expect(c.mentions, isEmpty);
  });

  test('the Backspace-and-retype of Unikey around a mention keeps it', () {
    // "a" → "â" after the mention: Unikey deletes "a", then types "â".
    type('a', 9);
    backspace(10);
    type('â', 9);
    expect(c.text, 'hi @Dyno â');
    expect(c.mentions, [(start: 3, end: 8, id: 41)]);
  });

  test('clear drops the mentions', () {
    c.clear();
    expect(c.mentions, isEmpty);
  });
}
