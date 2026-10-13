import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/value_objects/markdown_format.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_composer_controller.dart';

void main() {
  late ChatComposerController c;

  setUp(() => c = ChatComposerController(markdown: true));
  tearDown(() => c.dispose());

  void select(int start, [int? end]) => c.quill.updateSelection(
    TextSelection(baseOffset: start, extentOffset: end ?? start),
    ChangeSource.local,
  );

  test('formats the selection and writes it as Markdown', () {
    c.insertText('say hi');
    select(4, 6);
    c.apply(MarkdownFormat.bold);
    expect(c.isOn(MarkdownFormat.bold), isTrue);
    expect(c.messageText, 'say **hi**');

    c.apply(MarkdownFormat.bold);
    expect(c.messageText, 'say hi');

    c.apply(MarkdownFormat.bulletList);
    expect(c.messageText, '- say hi');
  });

  test('a mention is one unit that keeps its id', () {
    c.insertText('ping @dy');
    c.insertMention(5, 8, id: 41, name: 'Dyno');
    expect(c.plainText, 'ping ￼ ');
    expect(c.quill.selection, const TextSelection.collapsed(offset: 7));
    expect(c.hasMentions, isTrue);
    expect(c.messageText, 'ping [@Dyno](@#41) ');
  });

  test('@all is written as text', () {
    c.insertText('@a');
    c.insertMention(0, 2, name: 'all');
    expect(c.messageText, '@all ');
    expect(c.hasMentions, isFalse);
  });

  test('turning Markdown off keeps the text and mentions, not formatting', () {
    c.insertText('hi @d');
    c.insertMention(3, 5, id: 41, name: 'Dyno');
    select(0, 2);
    c.apply(MarkdownFormat.italic);
    c.markdown = false;
    expect(c.plainText, 'hi @Dyno ');
    expect(c.messageText, 'hi [@Dyno](@#41) ');
    expect(c.quill.document.toDelta().toJson(), [
      {'insert': '\n'},
    ]);
  });

  test('turning Markdown on carries plain text and mentions across', () {
    c.markdown = false;
    c.insertText('hi @d');
    c.insertMention(3, 5, id: 41, name: 'Dyno');
    c.markdown = true;
    expect(c.plain.text, isEmpty);
    expect(c.plainText, 'hi ￼ ');
    expect(c.quill.selection, const TextSelection.collapsed(offset: 5));
    expect(c.messageText, 'hi [@Dyno](@#41) ');
  });

  test('plain mode: a mention reads as placeholders, not an @query', () {
    c.markdown = false;
    c.insertText('@d');
    c.insertMention(0, 2, id: 41, name: 'Dyno');
    expect(c.value.text, '￼￼￼￼￼ ');
    expect(c.hasMentions, isTrue);
    expect(c.messageText, '[@Dyno](@#41) ');
    c.clear();
    expect(c.isBlank, isTrue);
    expect(c.hasMentions, isFalse);
  });

  test('clear empties text and formatting', () {
    c.insertText('x');
    select(0, 1);
    c.apply(MarkdownFormat.heading);
    c.clear();
    expect(c.isBlank, isTrue);
    expect(c.quill.document.toDelta().toJson(), [
      {'insert': '\n'},
    ]);
  });
}
