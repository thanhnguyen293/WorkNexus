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

  test('turning Markdown off strips the formatting', () {
    c.insertText('hi');
    select(0, 2);
    c.apply(MarkdownFormat.italic);
    c.markdown = false;
    expect(c.quill.document.toDelta().toJson(), [
      {'insert': 'hi\n'},
    ]);
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
