// Quill marks its clipboard options experimental; plain-text paste needs them.
// ignore_for_file: experimental_member_use

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

import '../../domain/usecases/build_message_text.dart';
import '../../domain/value_objects/markdown_format.dart';
import 'chat_mention_embed.dart';
import 'chat_mention_text_controller.dart';

/// What is being typed in the composer, written out as the message's text
/// when it is sent (see [BuildMessageText]). With Markdown on it is rich text
/// in [quill] (formatting is a property of the text, never hidden syntax);
/// off, it is [plain] text in a platform text field. Switching carries the
/// text and its mentions across.
class ChatComposerController implements Listenable {
  ChatComposerController({bool markdown = false}) : _markdown = markdown;

  /// Pasting brings text only: what the toolbar can make is what is sent.
  final quill = QuillController(
    document: Document(),
    selection: const TextSelection.collapsed(offset: 0),
    config: const QuillControllerConfig(
      clipboardConfig: QuillClipboardConfig(enableExternalRichPaste: false),
    ),
  );

  /// The text with Markdown off. A plain [TextEditingController] leaves
  /// typing to the platform's text input as is, which IMEs that rewrite what
  /// was typed (Unikey's Backspace-and-retype) depend on.
  final plain = ChatMentionTextController();

  bool _markdown;

  /// Whether formatting is kept (sent as Markdown). Turning it off drops
  /// the formatting there is, so what shows is what is sent.
  bool get markdown => _markdown;
  set markdown(bool on) {
    if (on == _markdown) return;
    _markdown = on;
    on ? _toQuill() : _toPlain();
  }

  @override
  void addListener(VoidCallback listener) {
    quill.addListener(listener);
    plain.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    quill.removeListener(listener);
    plain.removeListener(listener);
  }

  List<Map<String, dynamic>> get _ops =>
      _markdown ? quill.document.toDelta().toJson() : _plainOps;

  /// [plain] as operations: its text, each mention an embed.
  List<Map<String, dynamic>> get _plainOps {
    final text = plain.text;
    final ops = <Map<String, dynamic>>[];
    var at = 0;
    for (final m in plain.mentions) {
      if (m.start > at) ops.add({'insert': text.substring(at, m.start)});
      final name = text.substring(m.start + 1, m.end);
      ops.add({'insert': ChatMentionEmbed(id: m.id, name: name).toJson()});
      at = m.end;
    }
    if (at < text.length) ops.add({'insert': text.substring(at)});
    return ops;
  }

  /// The message to send.
  String get messageText => const BuildMessageText()(_ops, markdown: _markdown);

  /// The text: with Markdown on, each embed as one placeholder character so
  /// offsets are the document's (without its closing line break); off, as
  /// shown, mentions as `@Name`.
  String get plainText {
    if (!_markdown) return plain.text;
    final out = StringBuffer();
    for (final op in quill.document.toDelta().toList()) {
      final data = op.data;
      out.write(data is String ? data : Embed.kObjectReplacementCharacter);
    }
    final text = out.toString();
    return text.endsWith('\n') ? text.substring(0, text.length - 1) : text;
  }

  /// The text with the selection, for reading what is before the caret. A
  /// mention reads as placeholder characters, so it never reads as an
  /// `@query` being typed.
  TextEditingValue get value {
    if (_markdown) {
      return TextEditingValue(text: plainText, selection: quill.selection);
    }
    final units = List.of(plain.text.codeUnits);
    for (final m in plain.mentions) {
      units.fillRange(m.start, m.end, Embed.kObjectReplacementInt);
    }
    return TextEditingValue(
      text: String.fromCharCodes(units),
      selection: plain.selection,
    );
  }

  TextSelection get selection => _markdown ? quill.selection : plain.selection;

  bool get isBlank => plainText.trim().isEmpty;

  bool get hasMentions => _markdown
      ? _ops.any(
          (op) => switch (op['insert']) {
            {ChatMentionEmbed.kind: _} => true,
            _ => false,
          },
        )
      : plain.mentions.isNotEmpty;

  /// The selection, or the end of the text when there is none.
  TextSelection get _selection {
    final selection = quill.selection;
    if (selection.isValid) return selection;
    return TextSelection.collapsed(offset: plainText.length);
  }

  /// Puts [text] in place of the selection.
  void insertText(String text) {
    if (!_markdown) return plain.replaceSelection(text);
    final selection = _selection;
    quill.replaceText(
      selection.start,
      selection.end - selection.start,
      text,
      TextSelection.collapsed(offset: selection.start + text.length),
    );
  }

  /// Replaces [start]–[end] (the typed `@query`) with a mention of [name]
  /// and a space. Without an [id] (`@all`) it is written as text.
  void insertMention(int start, int end, {int? id, required String name}) {
    if (!_markdown) {
      return id == null
          ? plain.replace(start, end, '@$name ')
          : plain.insertMention(start, end, id: id, name: name);
    }
    if (id == null) {
      final text = '@$name ';
      quill.replaceText(
        start,
        end - start,
        text,
        TextSelection.collapsed(offset: start + text.length),
      );
      return;
    }
    quill.compose(
      Delta()
        ..retain(start)
        ..delete(end - start)
        ..insert(ChatMentionEmbed(id: id, name: name).toJson())
        ..insert(' '),
      TextSelection.collapsed(offset: start + 2),
      ChangeSource.local,
    );
  }

  /// Whether the selection has [format] (indent and clear never "are on").
  bool isOn(MarkdownFormat format) {
    final attribute = _attribute(format);
    if (attribute == null) return false;
    final current = quill.getSelectionStyle().attributes[attribute.key];
    return current?.value == attribute.value;
  }

  /// Applies [format] to the selection, or takes it off when it is on.
  void apply(MarkdownFormat format) {
    switch (format) {
      case MarkdownFormat.indent:
        quill.indentSelection(true);
      case MarkdownFormat.outdent:
        quill.indentSelection(false);
      case MarkdownFormat.clear:
        final keys = {
          for (final style in quill.getAllSelectionStyles())
            ...style.attributes.keys,
        };
        for (final key in keys) {
          if (Attribute.fromKeyValue(key, null) case final attribute?) {
            quill.formatSelection(attribute);
          }
        }
      default:
        final attribute = _attribute(format)!;
        quill.formatSelection(
          isOn(format) ? Attribute.clone(attribute, null) : attribute,
        );
    }
  }

  static Attribute<Object?>? _attribute(MarkdownFormat format) =>
      switch (format) {
        MarkdownFormat.bold => Attribute.bold,
        MarkdownFormat.italic => Attribute.italic,
        MarkdownFormat.underline => Attribute.underline,
        MarkdownFormat.strikethrough => Attribute.strikeThrough,
        MarkdownFormat.code => Attribute.inlineCode,
        MarkdownFormat.heading => Attribute.h1,
        MarkdownFormat.quote => Attribute.blockQuote,
        MarkdownFormat.bulletList => Attribute.ul,
        MarkdownFormat.numberedList => Attribute.ol,
        MarkdownFormat.indent ||
        MarkdownFormat.outdent ||
        MarkdownFormat.clear => null,
      };

  /// Moves [plain]'s text and mentions into [quill], the caret at the end.
  void _toQuill() {
    final delta = Delta();
    for (final op in _plainOps) {
      delta.insert(op['insert']);
    }
    delta.insert('\n');
    quill.document = Document.fromDelta(delta);
    quill.updateSelection(
      TextSelection.collapsed(offset: quill.document.length - 1),
      ChangeSource.local,
    );
    plain.clear();
  }

  /// Moves [quill]'s text and mentions into [plain], without formatting.
  void _toPlain() {
    final out = StringBuffer();
    final mentions = <ChatTextMention>[];
    for (final op in quill.document.toDelta().toList()) {
      switch (op.data) {
        case final String text:
          out.write(text);
        case {
          ChatMentionEmbed.kind: {
            'id': final int id,
            'name': final String name,
          },
        }:
          final start = out.length;
          out.write('@$name');
          mentions.add((start: start, end: out.length, id: id));
      }
    }
    final text = out.toString();
    _clearQuill();
    plain.setContent(
      text.endsWith('\n') ? text.substring(0, text.length - 1) : text,
      mentions,
    );
  }

  void _clearQuill() => quill
    ..document = Document()
    ..toggledStyle = const Style();

  /// Empties the composer (after sending), formatting and history too.
  void clear() => _markdown ? _clearQuill() : plain.clear();

  void dispose() {
    quill.dispose();
    plain.dispose();
  }
}
