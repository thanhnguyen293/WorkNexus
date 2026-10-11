import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../core/widgets/app_input_decoration.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../core/widgets/quick_settings_segmented.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/value_objects/chat_group_avatar.dart';
import '../providers/chat_providers.dart';
import 'chat_attachments.dart';
import 'chat_avatar.dart';
import 'chat_labels.dart';
import 'chat_snack.dart';

/// Colours offered for a text avatar — the official client's palette, so
/// both clients show the same choices. Data sent to the server, not theme
/// colours, hence the literals.
const _kColors = [
  '#37C3A4', '#66ADFF', '#E05151', '#E0B751', '#A2E051', //
  '#51E067', '#7C51E0', '#E051DE', '#E05177', '#E09A51',
];

/// Changes a group's picture: a short text on a colour, or an image.
class ChatGroupAvatarDialog extends ConsumerStatefulWidget {
  const ChatGroupAvatarDialog({
    super.key,
    required this.thread,
    required this.chat,
    required this.title,
  });

  final ChatThreadKey thread;
  final ChatConversation chat;
  final String title;

  static Future<void> show(
    BuildContext context, {
    required ChatThreadKey thread,
    required ChatConversation chat,
    required String title,
  }) => showDialog<void>(
    context: context,
    builder: (_) =>
        ChatGroupAvatarDialog(thread: thread, chat: chat, title: title),
  );

  @override
  ConsumerState<ChatGroupAvatarDialog> createState() =>
      _ChatGroupAvatarDialogState();
}

class _ChatGroupAvatarDialogState extends ConsumerState<ChatGroupAvatarDialog> {
  late final _text = TextEditingController(
    text: switch (ChatGroupAvatar.fromJson(widget.chat.avatarJson)) {
      ChatTextAvatar(:final text) => text,
      _ => '',
    },
  );
  late String _hex = switch (ChatGroupAvatar.fromJson(widget.chat.avatarJson)) {
    ChatTextAvatar(:final color) when _kColors.contains(color) => color,
    _ => _kColors.first,
  };
  bool _imageMode = false;
  Uint8List? _image;
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final files = await pickChatAttachments(imagesOnly: true);
    if (files.isNotEmpty && mounted) {
      setState(() => _image = files.first.bytes);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final result = await ref
        .read(chatControllerProvider)
        .setGroupAvatar(
          widget.thread.accountId,
          widget.thread.chatGid,
          text: _imageMode ? null : _text.text.trim(),
          color: _imageMode ? null : _hex,
          image: _imageMode ? _image : null,
        );
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.of(context).pop();
      case Err(:final failure):
        setState(() => _saving = false);
        showChatFailure(context, failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final image = _image;
    final preview = _imageMode
        ? image == null
              ? ChatAvatar(name: widget.title, diameter: s.xl6 * 2.2)
              : ClipOval(
                  child: Image.memory(
                    image,
                    width: s.xl6 * 2.2,
                    height: s.xl6 * 2.2,
                    fit: BoxFit.cover,
                  ),
                )
        : ValueListenableBuilder(
            valueListenable: _text,
            builder: (context, value, _) => ChatAvatar(
              name: widget.title,
              label: value.text,
              background: chatHexColor(_hex),
              diameter: s.xl6 * 2.2,
            ),
          );
    final canSave = !_saving && !(_imageMode && image == null);
    return AppDialogFrame(
      title: l.chatChangeGroupAvatar,
      maxWidth: context.sizes.dialogSm,
      actions: [
        const Spacer(),
        AppButton.textNeutral(
          size: AppButtonSize.small,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.chatCancel),
        ),
        AppButton.filled(
          size: AppButtonSize.small,
          isLoading: _saving,
          isDisabled: _imageMode && image == null,
          onPressed: canSave ? _save : null,
          child: Text(l.chatSave),
        ),
      ],
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(s.xl3, 0, s.xl3, s.xl3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            QuickSettingsSegmented<bool>(
              value: _imageMode,
              options: {false: l.chatAvatarText, true: l.chatAvatarImage},
              onChanged: (v) => setState(() => _imageMode = v),
            ),
            SizedBox(height: s.xl4),
            Center(child: preview),
            SizedBox(height: s.xl4),
            if (_imageMode)
              Center(
                child: AppButton.outlinedNeutral(
                  size: AppButtonSize.small,
                  icon: LucideIcons.imageUp300,
                  onPressed: _pick,
                  child: Text(l.chatAvatarPick),
                ),
              )
            else ...[
              TextField(
                controller: _text,
                maxLength: 4,
                onSubmitted: (_) {
                  if (canSave) _save();
                },
                style: context.typography.body.copyWith(color: c.textPrimary),
                decoration: appInputDecoration(
                  context,
                  hint: l.chatAvatarTextHint,
                ),
              ),
              SizedBox(height: s.md),
              Wrap(
                spacing: s.md,
                runSpacing: s.md,
                children: [
                  for (final hex in _kColors)
                    HoverSurface(
                      onTap: () => setState(() => _hex = hex),
                      width: context.sizes.controlMd,
                      height: context.sizes.controlMd,
                      shape: BoxShape.circle,
                      color: chatHexColor(hex),
                      selected: hex == _hex,
                      semanticLabel: hex,
                      // The ring answers hover: a tint would shift the colour.
                      tintOnHover: false,
                      border: hex == _hex
                          ? Border.all(
                              color: c.textPrimary,
                              width: context.borders.thick,
                            )
                          : null,
                      hoverBorder: Border.all(
                        color: hex == _hex ? c.textPrimary : c.borderStrong,
                        width: context.borders.thick,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
