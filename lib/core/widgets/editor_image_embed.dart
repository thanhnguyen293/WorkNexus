import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'editor_image_frame.dart';
import 'html_editing_controller.dart';
import 'inline_image.dart';

/// Shows an image in the editor: through the authenticated loader when one
/// is given (ZenTao's images need the session), else from the network.
class EditorImageEmbedBuilder extends EmbedBuilder {
  const EditorImageEmbedBuilder({this.loader});

  final ImageBytesLoader? loader;

  @override
  String get key => BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final node = embedContext.node;
    final url = node.value.data.toString();
    final width = double.tryParse(
      imageStyleWidth(node.style.attributes[Attribute.style.key]?.value) ?? '',
    );
    final load = loader;
    return EditorImageFrame(
      width: width,
      onResize: embedContext.readOnly
          ? null
          : (w) => embedContext.controller.formatText(
              node.documentOffset,
              1,
              StyleAttribute(w == null ? null : 'width:${w.round()}px'),
            ),
      builder: (w) => load == null
          ? Image.network(url, width: w, fit: BoxFit.contain)
          : InlineImage(
              key: ValueKey(url),
              url: url,
              loader: load,
              width: w,
              // The frame spaces it, so its outline hugs the image.
              padding: EdgeInsets.zero,
            ),
    );
  }
}
