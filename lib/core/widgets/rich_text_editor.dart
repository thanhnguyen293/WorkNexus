import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../util/dropped_files.dart';
import 'editor_image_embed.dart';
import 'editor_toolbar_buttons.dart';
import 'file_drop_target.dart';
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
    this.onDropFiles,
  });

  final HtmlEditingController controller;

  /// Loads an image's bytes (authenticated) to show it in the editor.
  final ImageBytesLoader? imageLoader;

  /// Uploads a picked or pasted image; images cannot be added without it.
  final EditorImageUploader? onUploadImage;
  final double minHeight;
  final String? placeholder;

  /// Takes files dropped onto the editor that it can't show inline (anything
  /// but an image, or every file without [onUploadImage]); dropping is off
  /// when neither can take a file.
  final ValueChanged<List<DroppedFile>>? onDropFiles;

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
    await _insertImage(await file.readAsBytes(), file.name);
  }

  /// Uploads an image and puts it at the cursor.
  Future<void> _insertImage(Uint8List bytes, String name) async {
    final url = await _upload(bytes, name);
    if (url == null || !mounted) return;
    final quill = widget.controller.quill;
    final at = quill.selection.baseOffset < 0 ? 0 : quill.selection.baseOffset;
    quill.replaceText(at, 0, BlockEmbed.image(url), null);
  }

  /// Images go inline (when they can be uploaded); the rest to [onDropFiles].
  Future<void> _drop(List<DroppedFile> files) async {
    final canUpload = widget.onUploadImage != null;
    final split = splitDroppedImages(files);
    final others = [...split.others, if (!canUpload) ...split.images];
    if (others.isNotEmpty) widget.onDropFiles?.call(others);
    if (!canUpload) return;
    for (final image in split.images) {
      await _insertImage(image.bytes, image.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final quill = widget.controller.quill;
    return FileDropTarget(
      enabled: widget.onUploadImage != null || widget.onDropFiles != null,
      hint: l.dropFilesToInsert,
      onDrop: _drop,
      child: Container(
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
              padding: EdgeInsets.symmetric(horizontal: s.xs, vertical: s.xxs),
              color: c.surfaceSubtle,
              child: QuillSimpleToolbar(
                controller: quill,
                config: QuillSimpleToolbarConfig(
                  color: c.surfaceSubtle,
                  sectionDividerColor: c.border,
                  buttonOptions: editorToolbarButtons(context, quill),
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
                                dimension: s.xl2,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 1.6,
                                ),
                              )
                            : Icon(LucideIcons.image300, size: s.xl2),
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
                    customStyles: _bodyStyles(context),
                    embedBuilders: [
                      EditorImageEmbedBuilder(loader: widget.imageLoader),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quill writes body text at 16 (placeholder 20), larger than the app's body
/// that the rendered description and comments use; every plain-text block is
/// set in that body size instead, with its placeholder alongside it.
DefaultStyles _bodyStyles(BuildContext context) {
  final c = context.colors;
  final body = DefaultTextStyle.of(context).style
      .merge(context.typography.body)
      .copyWith(
        color: c.textPrimary,
        height: 1.55,
        decoration: TextDecoration.none,
      );
  const none = HorizontalSpacing(0, 0);
  const gap = VerticalSpacing(6, 0);
  DefaultTextBlockStyle block(VerticalSpacing v, VerticalSpacing line) =>
      DefaultTextBlockStyle(body, none, v, line, null);
  return DefaultStyles(
    paragraph: block(VerticalSpacing.zero, VerticalSpacing.zero),
    placeHolder: DefaultTextBlockStyle(
      body.copyWith(color: c.textTertiary),
      none,
      VerticalSpacing.zero,
      VerticalSpacing.zero,
      null,
    ),
    lists: DefaultListBlockStyle(
      body,
      none,
      gap,
      const VerticalSpacing(0, 6),
      null,
      null,
    ),
    indent: block(gap, const VerticalSpacing(0, 6)),
    align: block(VerticalSpacing.zero, VerticalSpacing.zero),
    leading: block(VerticalSpacing.zero, VerticalSpacing.zero),
  );
}
