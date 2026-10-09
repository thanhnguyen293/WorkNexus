import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../util/dropped_files.dart';
import 'editor_color_button.dart';
import 'editor_image_embed.dart';
import 'editor_link_button.dart';
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
                  buttonOptions: QuillSimpleToolbarButtonOptions(
                    base: QuillToolbarBaseButtonOptions(
                      iconSize: s.xl2,
                      iconButtonFactor: 1.1,
                      iconTheme: _toolbarIconTheme(context),
                    ),
                    // Swatch drop-downs in place of quill's Material dialog. Quill
                    // calls the builder through a dynamic-typed function, so its
                    // parameters must be untyped (typed ones fail at runtime).
                    color: QuillToolbarColorButtonOptions(
                      childBuilder: (Object? _, Object? _) => EditorColorButton(
                        controller: quill,
                        isBackground: false,
                        iconSize: s.xl2 * 1.1,
                      ),
                    ),
                    linkStyle: QuillToolbarLinkStyleButtonOptions(
                      childBuilder: (Object? _, Object? _) => EditorLinkButton(
                        controller: quill,
                        iconSize: s.xl2 * 1.1,
                      ),
                    ),
                    backgroundColor: QuillToolbarColorButtonOptions(
                      childBuilder: (Object? _, Object? _) => EditorColorButton(
                        controller: quill,
                        isBackground: true,
                        iconSize: s.xl2 * 1.1,
                      ),
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
                                dimension: s.xl2,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 1.6,
                                ),
                              )
                            : Icon(PhosphorIconsLight.image, size: s.xl2),
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

/// Toolbar buttons in the app's tones: muted glyphs, and the active format
/// on a soft accent fill instead of Material's solid primary.
QuillIconTheme _toolbarIconTheme(BuildContext context) {
  final c = context.colors;
  final shape = WidgetStatePropertyAll(
    RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(context.radii.sm),
    ),
  );
  // Material's 40–48px touch targets spread the toolbar over two rows on a
  // desktop form; a snug button per glyph keeps it to one. A minimum, not a
  // fixed size: the paragraph-style picker shares this theme and is wider.
  final side = context.spacing.xl6 * 0.7;
  final style = ButtonStyle(
    shape: shape,
    minimumSize: WidgetStatePropertyAll(Size.square(side)),
    padding: WidgetStatePropertyAll(EdgeInsets.all(context.spacing.xs)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
  );
  return QuillIconTheme(
    iconButtonUnselectedData: IconButtonData(
      color: c.textSecondary,
      style: style,
    ),
    iconButtonSelectedData: IconButtonData(
      color: c.accent,
      style: style.copyWith(
        backgroundColor: WidgetStatePropertyAll(c.mixT(c.accent, 0.14)),
      ),
    ),
  );
}
