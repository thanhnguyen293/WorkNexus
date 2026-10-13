// Quill marks its clipboard options experimental; plain-text paste needs them.
// ignore_for_file: experimental_member_use

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

import '../../domain/usecases/build_message_text.dart';
import '../../domain/value_objects/markdown_format.dart';
import 'chat_mention_embed.dart';

/// What is being typed in the composer: rich text (formatting is a property
/// of the text, never hidden syntax) written out as the message's text —
/// Markdown, or plain — when it is sent (see [BuildMessageText]).
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

  bool _markdown;

  /// Whether formatting is kept (sent as Markdown). Turning it off strips
  /// the formatting there is, so what shows is what is sent.
  bool get markdown => _markdown;
  set markdown(bool on) {
    if (on == _markdown) return;
    _markdown = on;
    if (!on) _stripFormatting();
  }

  @override
  void addListener(VoidCallback listener) => quill.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => quill.removeListener(listener);

  List<Map<String, dynamic>> get _ops => quill.document.toDelta().toJson();

  /// The message to send.
  String get messageText =>
      const BuildMessageText()(_ops, markdown: _markdown);

  /// The text with each embed as one placeholder character, so offsets are
  /// the document's (without its closing line break).
  String get plainText {
    final out = StringBuffer();
    for (final op in quill.document.toDelta().toList()) {
      final data = op.data;
      out.write(data is String ? data : Embed.kObjectReplacementCharacter);
    }
    final text = out.toString();
    return text.endsWith('\n') ? text.substring(0, text.length - 1) : text;
  }

  /// [plainText] with the selection, for reading what is before the caret.
  TextEditingValue get value =>
      TextEditingValue(text: plainText, selection: quill.selection);

  bool get isBlank => plainText.trim().isEmpty;

  bool get hasMentions => _ops.any(
    (op) => switch (op['insert']) {
      {ChatMentionEmbed.kind: _} => true,
      _ => false,
    },
  );

  /// The selection, or the end of the text when there is none.
  TextSelection get _selection {
    final selection = quill.selection;
    if (selection.isValid) return selection;
    return TextSelection.collapsed(offset: plainText.length);
  }

  /// Puts [text] in place of the selection.
  void insertText(String text) {
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

  void _stripFormatting() {
    final keys = {
      for (final op in quill.document.toDelta().toList())
        ...?op.attributes?.keys,
    };
    final length = quill.document.length;
    for (final key in keys) {
      if (Attribute.fromKeyValue(key, null) case final attribute?) {
        quill.formatText(0, length, attribute);
      }
    }
    quill.toggledStyle = const Style();
  }

  /// Empties the composer (after sending), formatting and history too.
  void clear() {
    quill
      ..document = Document()
      ..toggledStyle = const Style();
  }

  void dispose() => quill.dispose();
}
