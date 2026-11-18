import 'package:flutter_quill/flutter_quill.dart';

import '../../domain/value_objects/markdown_format.dart';
import 'chat_composer_controller.dart';

/// The Markdown toolbar's formats on what is typed in the composer: whether
/// the selection has one, and applying or removing it. Formatting exists
/// with Markdown on only (in [ChatComposerController.quill]).
extension ChatComposerFormatting on ChatComposerController {
  /// Whether the selection has [format] (indent and clear never "are on").
  bool isOn(MarkdownFormat format) {
    final attribute = _formatAttribute(format);
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
        final attribute = _formatAttribute(format)!;
        quill.formatSelection(
          isOn(format) ? Attribute.clone(attribute, null) : attribute,
        );
    }
  }
}

/// The Quill attribute [format] sets; null for indent and clear, which are
/// actions rather than styles.
Attribute<Object?>? _formatAttribute(MarkdownFormat format) => switch (format) {
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
