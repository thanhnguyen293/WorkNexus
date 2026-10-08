import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';
import 'chat_attachments.dart';
import 'chat_image_viewer_bar.dart';
import 'chat_snack.dart';

/// Zoom steps of the viewer's buttons and keys.
const double _kMinScale = 0.25;
const double _kMaxScale = 8;
const double _kZoomStep = 1.25;

/// Full-screen image viewer: zoom (wheel, pinch, buttons, double-click),
/// pan, rotate, previous/next through the chat's images, copy, save and
/// open in the default app. Keys: ←/→, +/−, 0 (fit), R (rotate), Esc.
class ChatImageViewer extends ConsumerStatefulWidget {
  const ChatImageViewer({
    super.key,
    required this.accountId,
    required this.images,
    required this.initialIndex,
  });

  final String accountId;
  final List<ImageContent> images;
  final int initialIndex;

  static Future<void> show(
    BuildContext context, {
    required String accountId,
    required List<ImageContent> images,
    required int initialIndex,
  }) => showDialog<void>(
    context: context,
    barrierColor: context.colors.scrim.withValues(alpha: 0.9),
    builder: (_) => ChatImageViewer(
      accountId: accountId,
      images: images,
      initialIndex: initialIndex,
    ),
  );

  @override
  ConsumerState<ChatImageViewer> createState() => _ChatImageViewerState();
}

class _ChatImageViewerState extends ConsumerState<ChatImageViewer> {
  final _transform = TransformationController();
  late int _index = widget.initialIndex;
  int _turns = 0;

  ImageContent get _image => widget.images[_index];

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.images.length) return;
    setState(() {
      _index = next;
      _turns = 0;
      _transform.value = Matrix4.identity();
    });
  }

  void _zoom(double factor) {
    final current = _transform.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(_kMinScale, _kMaxScale);
    final size = MediaQuery.sizeOf(context);
    final center = Offset(size.width / 2, size.height / 2);
    // Zoom around the screen centre: move it to the origin, scale, move back.
    final focal = _transform.toScene(center);
    _transform.value = _transform.value.clone()
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(target / current, target / current, 1, 1)
      ..translateByDouble(-focal.dx, -focal.dy, 0, 1);
  }

  void _fit() => _transform.value = Matrix4.identity();

  void _rotate() => setState(() => _turns = (_turns + 1) % 4);

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
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
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
    final hasPrev = _index > 0;
    final hasNext = _index < widget.images.length - 1;

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
        child: Dialog.fullscreen(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onDoubleTap: () => _transform.value.getMaxScaleOnAxis() > 1.01
                      ? _fit()
                      : _zoom(2),
                  child: InteractiveViewer(
                    transformationController: _transform,
                    minScale: _kMinScale,
                    maxScale: _kMaxScale,
                    boundaryMargin: EdgeInsets.all(s.xl6 * 10),
                    child: Center(
                      child: bytes == null
                          ? const SizedBox.shrink()
                          : RotatedBox(
                              quarterTurns: _turns,
                              child: Image.memory(bytes, gaplessPlayback: true),
                            ),
                    ),
                  ),
                ),
              ),
              if (loading || failed)
                Center(
                  child: failed
                      ? Text(
                          l.chatAttachmentFailed,
                          style: context.typography.body.copyWith(
                            color: c.onScrim,
                          ),
                        )
                      : CircularProgressIndicator(color: c.onScrim),
                ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ChatImageViewerBar(
                  image: _image,
                  position: '${_index + 1} / ${widget.images.length}',
                  transform: _transform,
                  onZoomIn: () => _zoom(_kZoomStep),
                  onZoomOut: () => _zoom(1 / _kZoomStep),
                  onFit: _fit,
                  onRotate: _rotate,
                  onCopy: full is Ok ? _copy : null,
                  onSave: _save,
                  onOpenExternally: _openExternally,
                  onClose: () => Navigator.of(context).pop(),
                ),
              ),
              if (hasPrev)
                _SideArrow(
                  alignment: Alignment.centerLeft,
                  icon: Icons.chevron_left_rounded,
                  tooltip: l.chatPrevious,
                  onPressed: () => _go(-1),
                ),
              if (hasNext)
                _SideArrow(
                  alignment: Alignment.centerRight,
                  icon: Icons.chevron_right_rounded,
                  tooltip: l.chatNext,
                  onPressed: () => _go(1),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round previous/next button on the viewer's left or right edge.
class _SideArrow extends StatelessWidget {
  const _SideArrow({
    required this.alignment,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final Alignment alignment;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Align(
      alignment: alignment,
      child: Padding(
        padding: EdgeInsets.all(context.spacing.xl4),
        child: IconButton.filled(
          tooltip: tooltip,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: c.scrim.withValues(alpha: 0.5),
            foregroundColor: c.onScrim,
          ),
          iconSize: context.spacing.xl6 * 0.8,
          icon: Icon(icon),
        ),
      ),
    );
  }
}
