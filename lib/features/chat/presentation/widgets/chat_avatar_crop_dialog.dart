import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/chat_avatar_crop.dart';
import 'chat_avatar_crop_view.dart';

/// At most this share of the window's height goes to the picture, so a tall
/// one still leaves room for the dialog's title and buttons.
const _kPictureHeightShare = 0.6;

/// Lets the user pick the square of [image] that becomes their avatar.
/// Resolves to that square, or null when cancelled.
class ChatAvatarCropDialog extends StatefulWidget {
  const ChatAvatarCropDialog({super.key, required this.image});

  final Uint8List image;

  static Future<ChatAvatarCrop?> show(BuildContext context, Uint8List image) =>
      showDialog<ChatAvatarCrop>(
        context: context,
        builder: (_) => ChatAvatarCropDialog(image: image),
      );

  @override
  State<ChatAvatarCropDialog> createState() => _ChatAvatarCropDialogState();
}

class _ChatAvatarCropDialogState extends State<ChatAvatarCropDialog> {
  late final _provider = MemoryImage(widget.image);
  ImageStream? _stream;
  late final _listener = ImageStreamListener((info, _) {
    final image = info.image;
    setState(
      () => _size = Size(image.width.toDouble(), image.height.toDouble()),
    );
    info.dispose();
  }, onError: (_, _) => setState(() => _unreadable = true));

  /// The picture's size in px, once decoded.
  Size? _size;
  bool _unreadable = false;
  ChatAvatarCrop? _crop;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream?.removeListener(_listener);
    _stream = _provider.resolve(createLocalImageConfiguration(context))
      ..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final l = AppL10n.of(context);
    final size = _size;
    final padding = s.xl3;
    final width = context.sizes.dialogLg - padding * 2;
    final Widget body;
    if (_unreadable) {
      body = Center(
        child: AppInlineNote(text: l.chatCropAvatarUnreadable, isError: true),
      );
    } else if (size == null) {
      body = const AppInlineSpinner();
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChatAvatarCropView(
            image: _provider,
            imageSize: size,
            maxSize: Size(
              width,
              math.min(
                width,
                MediaQuery.sizeOf(context).height * _kPictureHeightShare,
              ),
            ),
            onChanged: (crop) => _crop = crop,
          ),
          SizedBox(height: s.md),
          Text(
            l.chatCropAvatarHint,
            textAlign: TextAlign.center,
            style: context.typography.bodySm.copyWith(
              color: context.colors.textTertiary,
            ),
          ),
        ],
      );
    }
    return AppDialogFrame(
      title: l.chatCropAvatarTitle,
      maxWidth: context.sizes.dialogLg,
      actions: [
        const Spacer(),
        AppButton.textNeutral(
          size: AppButtonSize.small,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.chatCancel),
        ),
        AppButton.filled(
          size: AppButtonSize.small,
          isDisabled: size == null,
          onPressed: size == null
              ? null
              : () => Navigator.of(context).pop(_crop),
          child: Text(l.chatCropAvatarApply),
        ),
      ],
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
        child: body,
      ),
    );
  }
}
