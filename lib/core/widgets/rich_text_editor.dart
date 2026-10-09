import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import 'editor_image_frame.dart';
import 'html_editing_controller.dart';
import 'inline_image.dart';

/// Uploads an image put into the editor (picked or pasted) and returns the URL
/// to show it at, or null when it could not be uploaded.
typedef EditorImageUploader =
    Future<String?> Function(Uint8List bytes, String fileName);

/// A rich-text editor with the formatting ZenTao's web editor offers —
/// headings, bold / italic / underline / strike, colours, lists, quotes, code,
/// links, alignment, indent and images — reading and writing HTML through
/// [controller].
class RichTextEditor extends StatefulWidget {
  const RichTextEditor({
    super.key,
    required this.controller,
    this.imageLoader,
    this.onUploadImage,
    this.minHeight = 220,
    this.placeholder,
  });

  final HtmlEditingController controller;

  /// Loads an image's bytes (authenticated) to show it in the editor.
  final ImageBytesLoader? imageLoader;

  /// Uploads a picked or pasted image; images cannot be added without it.
  final EditorImageUploader? onUploadImage;
  final double minHeight;
  final String? placeholder;

  @override
  State<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends State<RichTextEditor> {
  final _focus = FocusNode();
  final _scroll = ScrollController();
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.onUploadImage != null) {
      widget.controller.onImagePaste = (bytes) =>
          _upload(bytes, 'pasted-${DateTime.now().millisecondsSinceEpoch}.png');
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<String?> _upload(Uint8List bytes, String name) async {
    final upload = widget.onUploadImage;
    if (upload == null) return null;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = AppL10n.of(context).imageUploadFailed;
    setState(() => _uploading = true);
    final url = await upload(bytes, name);
    if (mounted) setState(() => _uploading = false);
    if (url == null) messenger?.showSnackBar(SnackBar(content: Text(failed)));
    return url;
  }

  Future<void> _pickImage() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'images',
          extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'],
        ),
      ],
    );
    if (file == null) return;
    final url = await _upload(await file.readAsBytes(), file.name);
    if (url == null || !mounted) return;
    final quill = widget.controller.quill;
    final at = quill.selection.baseOffset < 0 ? 0 : quill.selection.baseOffset;
    quill.replaceText(at, 0, BlockEmbed.image(url), null);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final quill = widget.controller.quill;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(context.radii.md),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xs),
            color: c.surfaceSubtle,
            child: QuillSimpleToolbar(
              controller: quill,
              config: QuillSimpleToolbarConfig(
                color: c.surfaceSubtle,
                sectionDividerColor: c.border,
                buttonOptions: QuillSimpleToolbarButtonOptions(
                  base: QuillToolbarBaseButtonOptions(
                    iconSize: s.xl3,
                    iconButtonFactor: 1.1,
                    iconTheme: _toolbarIconTheme(context),
                  ),
                ),
                multiRowsDisplay: true,
                toolbarIconAlignment: WrapAlignment.start,
                showFontFamily: false,
                showFontSize: false,
                showSmallButton: false,
                showSearchButton: false,
                showSubscript: false,
                showSuperscript: false,
                showClipboardCut: false,
                showClipboardCopy: false,
                showClipboardPaste: false,
                customButtons: [
                  if (widget.onUploadImage != null)
                    QuillToolbarCustomButtonOptions(
                      tooltip: l.insertImage,
                      icon: _uploading
                          ? SizedBox.square(
                              dimension: s.xl3,
                              child: const CircularProgressIndicator(
                                strokeWidth: 1.6,
                              ),
                            )
                          : Icon(PhosphorIconsLight.image, size: s.xl3),
                      onPressed: _uploading ? null : _pickImage,
                    ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: c.border),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: widget.minHeight),
            child: Padding(
              padding: EdgeInsets.all(s.lg),
              child: QuillEditor(
                controller: quill,
                focusNode: _focus,
                scrollController: _scroll,
                config: QuillEditorConfig(
                  scrollable: false,
                  minHeight: widget.minHeight,
                  placeholder: widget.placeholder,
                  embedBuilders: [
                    _ImageEmbedBuilder(loader: widget.imageLoader),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Toolbar buttons in the app's tones: muted glyphs, and the active format
/// on a soft accent fill instead of Material's solid primary.
QuillIconTheme _toolbarIconTheme(BuildContext context) {
  final c = context.colors;
  final shape = WidgetStatePropertyAll(
    RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(context.radii.sm),
    ),
  );
  return QuillIconTheme(
    iconButtonUnselectedData: IconButtonData(
      color: c.textSecondary,
      style: ButtonStyle(shape: shape),
    ),
    iconButtonSelectedData: IconButtonData(
      color: c.accent,
      style: ButtonStyle(
        shape: shape,
        backgroundColor: WidgetStatePropertyAll(c.mixT(c.accent, 0.14)),
      ),
    ),
  );
}

/// Shows an image in the editor: through the authenticated loader when one
/// is given (ZenTao's images need the session), else from the network.
class _ImageEmbedBuilder extends EmbedBuilder {
  const _ImageEmbedBuilder({this.loader});

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
      child: load == null
          ? Image.network(url, width: width, fit: BoxFit.contain)
          : InlineImage(
              key: ValueKey(url),
              url: url,
              loader: load,
              width: width,
            ),
    );
  }
}
