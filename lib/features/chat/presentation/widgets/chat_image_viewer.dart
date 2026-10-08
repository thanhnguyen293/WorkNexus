import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';
import 'chat_attachments.dart';
import 'chat_image_stage.dart';
import 'chat_image_viewer_bar.dart';
import 'chat_media_strip.dart';
import 'chat_media_viewer_frame.dart';
import 'chat_snack.dart';
import 'chat_video_dialog.dart';
import 'save_sticker_action.dart';

/// Zoom steps of the viewer's buttons and keys.
const double _kMinScale = 0.25;
const double _kMaxScale = 8;
const double _kZoomStep = 1.25;

/// The image viewer, centred over the chat: zoom (wheel, pinch, buttons, double-click),
/// pan, rotate, previous/next through the chat's images, copy, save and
/// open in the default app. Keys: ←/→, +/−, 0 (fit), R (rotate), Esc.
class ChatImageViewer extends ConsumerStatefulWidget {
  const ChatImageViewer({
    super.key,
    required this.accountId,
    required this.images,
    required this.initialIndex,
    this.chatGid,
  });

  final String accountId;
  final List<ImageContent> images;
  final int initialIndex;

  /// The chat the images are from: its photos and videos then show in a
  /// strip along the bottom, and previous/next go through all its photos.
  final String? chatGid;

  static Future<void> show(
    BuildContext context, {
    required String accountId,
    required List<ImageContent> images,
    required int initialIndex,
    String? chatGid,
  }) => showDialog<void>(
    context: context,
    barrierColor: context.colors.scrim.withValues(
      alpha: kChatViewerBarrierAlpha,
    ),
    builder: (_) => ChatImageViewer(
      accountId: accountId,
      images: images,
      initialIndex: initialIndex,
      chatGid: chatGid,
    ),
  );

  @override
  ConsumerState<ChatImageViewer> createState() => _ChatImageViewerState();
}

class _ChatImageViewerState extends ConsumerState<ChatImageViewer> {
  final _transform = TransformationController();
  late ImageContent _image = widget.images[widget.initialIndex];
  int _turns = 0;

  /// The images previous/next go through: the chat's, once known.
  List<ImageContent> _images = const [];

  /// Size of the image area (below the bar), for zooming about its centre.
  Size _viewport = Size.zero;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = indexOfChatMedia(_images, _image) + delta;
    if (next >= 0 && next < _images.length) _show(_images[next]);
  }

  void _show(ImageContent image) => setState(() {
    _image = image;
    _turns = 0;
    _transform.value = Matrix4.identity();
  });

  /// A strip pick: another photo shows here; a video opens the player in
  /// this viewer's place.
  void _pick(MessageContent media) {
    if (media case final ImageContent image) return _show(image);
    if (media is! FileContent) return;
    final navigator = Navigator.of(context)..pop();
    ChatVideoDialog.show(
      navigator.context,
      accountId: widget.accountId,
      video: media,
      chatGid: widget.chatGid,
    );
  }

  void _zoom(double factor) {
    final current = _transform.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(_kMinScale, _kMaxScale);
    final center = Offset(_viewport.width / 2, _viewport.height / 2);
    // Zoom around the screen centre: move it to the origin, scale, move back.
    final focal = _transform.toScene(center);
    _transform.value = _transform.value.clone()
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(target / current, target / current, 1, 1)
      ..translateByDouble(-focal.dx, -focal.dy, 0, 1);
  }

  void _fit() => _transform.value = Matrix4.identity();

  void _rotate() => setState(() => _turns = (_turns + 1) % 4);

  /// Images saved as stickers while the viewer is open.
  final _stickers = <ImageContent>{};

  Future<void> _saveSticker(ImageContent image) async {
    final saved = await saveImageAsSticker(
      context,
      ref,
      accountId: widget.accountId,
      image: image,
    );
    if (saved && mounted) setState(() => _stickers.add(image));
  }

  Future<void> _copy() async {
    final l = AppL10n.of(context);
    final bytes = await ref.read(
      chatAttachmentProvider((
        accountId: widget.accountId,
        content: _image,
        thumbnail: false,
      )).future,
    );
    if (bytes case Ok(:final value)) {
      await copyImageToClipboard(value);
      if (mounted) showChatSnack(context, l.chatCopied);
    }
  }

  Future<void> _withFile(Future<void> Function(String path) use) async {
    final path = await ref
        .read(chatControllerProvider)
        .attachmentFile(widget.accountId, _image);
    if (!mounted) return;
    switch (path) {
      case Ok(:final value):
        await use(value);
      case Err(:final failure):
        showChatFailure(context, failure);
    }
  }

  Future<void> _save() => _withFile((path) async {
    final l = AppL10n.of(context);
    if (await saveAttachmentAs(path, _image.name) && mounted) {
      showChatSnack(context, l.chatSaved);
    }
  });

  Future<void> _openExternally() => _withFile(openExternally);

  @override
  Widget build(BuildContext context) {
    final key = (
      accountId: widget.accountId,
      content: _image as MessageContent,
      thumbnail: false,
    );
    final full = ref.watch(chatAttachmentProvider(key)).value;
    final preview = ref
        .watch(
          chatAttachmentProvider((
            accountId: widget.accountId,
            content: _image,
            thumbnail: true,
          )),
        )
        .value;
    final bytes = switch (full) {
      Ok(:final value) => value,
      _ => switch (preview) {
        Ok(:final value) => value,
        _ => null,
      },
    };
    final loading = full == null;
    final failed = full is Err;
    final chatGid = widget.chatGid;
    final thread = chatGid == null
        ? null
        : (accountId: widget.accountId, chatGid: chatGid);
    final chatImages = thread == null
        ? const <ImageContent>[]
        : chatMediaOf(ref, thread).whereType<ImageContent>().toList();
    final inChat = indexOfChatMedia(chatImages, _image);
    _images = inChat >= 0 ? chatImages : widget.images;
    final index = inChat >= 0 ? inChat : _images.indexOf(_image);
    final hasPrev = index > 0;
    final hasNext = index >= 0 && index < _images.length - 1;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _go(1),
        const SingleActivator(LogicalKeyboardKey.equal): () =>
            _zoom(_kZoomStep),
        const SingleActivator(LogicalKeyboardKey.add): () => _zoom(_kZoomStep),
        const SingleActivator(LogicalKeyboardKey.minus): () =>
            _zoom(1 / _kZoomStep),
        const SingleActivator(LogicalKeyboardKey.digit0): _fit,
        const SingleActivator(LogicalKeyboardKey.keyR): _rotate,
      },
      child: Focus(
        autofocus: true,
        child: ChatMediaViewerFrame(
          child: Column(
            children: [
              ChatImageViewerBar(
                image: _image,
                position: '${index + 1} / ${_images.length}',
                transform: _transform,
                onZoomIn: () => _zoom(_kZoomStep),
                onZoomOut: () => _zoom(1 / _kZoomStep),
                onFit: _fit,
                onRotate: _rotate,
                onCopy: full is Ok ? _copy : null,
                onSave: _save,
                onSaveSticker: _stickers.contains(_image)
                    ? null
                    : () => _saveSticker(_image),
                onOpenExternally: _openExternally,
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _viewport = constraints.biggest;
                    return ChatImageStage(
                      transform: _transform,
                      bytes: bytes,
                      turns: _turns,
                      minScale: _kMinScale,
                      maxScale: _kMaxScale,
                      roomForArrows: _images.length > 1,
                      loading: loading,
                      failed: failed,
                      onDoubleTap: () =>
                          _transform.value.getMaxScaleOnAxis() > 1.01
                          ? _fit()
                          : _zoom(2),
                      onPrevious: hasPrev ? () => _go(-1) : null,
                      onNext: hasNext ? () => _go(1) : null,
                    );
                  },
                ),
              ),
              if (thread != null)
                ChatMediaStrip(thread: thread, current: _image, onPick: _pick),
            ],
          ),
        ),
      ),
    );
  }
}
