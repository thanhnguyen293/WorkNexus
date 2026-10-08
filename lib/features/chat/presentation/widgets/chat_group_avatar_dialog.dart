import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/value_objects/chat_group_avatar.dart';
import '../providers/chat_providers.dart';
import 'chat_attachments.dart';
import 'chat_avatar.dart';
import 'chat_labels.dart';
import 'chat_snack.dart';

/// Colours offered for a text avatar — the official client's palette, so
/// both clients show the same choices.
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
    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: EdgeInsets.all(s.xl5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.chatChangeGroupAvatar,
                style: context.typography.titleLg.copyWith(
                  color: c.textPrimary,
                ),
              ),
              SizedBox(height: s.xl3),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(l.chatAvatarText)),
                  ButtonSegment(value: true, label: Text(l.chatAvatarImage)),
                ],
                selected: {_imageMode},
                onSelectionChanged: (v) => setState(() => _imageMode = v.first),
              ),
              SizedBox(height: s.xl4),
              Center(child: preview),
              SizedBox(height: s.xl4),
              if (_imageMode)
                Center(
                  child: AppButton.outlinedNeutral(
                    onPressed: _pick,
                    child: Text(l.chatAvatarPick),
                  ),
                )
              else ...[
                TextField(
                  controller: _text,
                  maxLength: 4,
                  decoration: InputDecoration(
                    labelText: l.chatAvatarText,
                    helperText: l.chatAvatarTextHint,
                    isDense: true,
                  ),
                ),
                SizedBox(height: s.md),
                Wrap(
                  spacing: s.md,
                  runSpacing: s.md,
                  children: [
                    for (final hex in _kColors)
                      InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => _hex = hex),
                        child: Container(
                          width: s.xl6 * 0.8,
                          height: s.xl6 * 0.8,
                          decoration: BoxDecoration(
                            color: chatHexColor(hex),
                            shape: BoxShape.circle,
                            border: hex == _hex
                                ? Border.all(color: c.textPrimary, width: 2.5)
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              SizedBox(height: s.xl4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton.textNeutral(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l.chatCancel),
                  ),
                  SizedBox(width: s.md),
                  AppButton.filled(
                    isLoading: _saving,
                    isDisabled: _imageMode && image == null,
                    onPressed: _saving || (_imageMode && image == null)
                        ? null
                        : _save,
                    child: Text(l.chatSave),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
