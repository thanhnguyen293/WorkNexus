import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_providers.dart';
import 'chat_ai_compose_button.dart';
import 'chat_composer_controller.dart';
import 'chat_emoji_picker.dart';
import 'chat_reply_suggestions_bar.dart';
import 'chat_send_code_button.dart';
import 'chat_sticker_suggestions_bar.dart';

/// The composer's tool row (above the input): send image, attach file,
/// mention someone, emoji, send code, AI writing help and the Markdown
/// toggle — with the replies the AI suggested, when asked, and stickers for
/// what is typed (or to answer with), above it.
class ChatComposerTools extends StatelessWidget {
  const ChatComposerTools({
    super.key,
    required this.onPickImage,
    required this.onAttach,
    required this.onMention,
    required this.thread,
    required this.draftKey,
    this.threadRootId,
    required this.text,
    required this.focus,
  });

  final ChatThreadKey thread;

  /// Whose reply draft (or thread root) a code snippet answers.
  final ChatComposerKey draftKey;
  final int? threadRootId;

  /// The input and its focus, for inserting emoji at the cursor.
  final ChatComposerController text;
  final FocusNode focus;
  final VoidCallback onPickImage;
  final VoidCallback onAttach;
  final VoidCallback onMention;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final tools = Padding(
      padding: EdgeInsets.symmetric(horizontal: s.lg, vertical: s.xs),
      child: Row(
        children: [
          ChatComposerToolButton(
            icon: LucideIcons.image300,
            tooltip: l.chatSendImage,
            onPressed: onPickImage,
          ),
          ChatComposerToolButton(
            icon: LucideIcons.paperclip300,
            tooltip: l.chatAttach,
            onPressed: onAttach,
          ),
          ChatComposerToolButton(
            icon: LucideIcons.atSign300,
            tooltip: l.chatMention,
            onPressed: onMention,
          ),
          ChatEmojiButton(
            thread: thread,
            text: text,
            focus: focus,
            dockable: !draftKey.inThread,
            threadRootId: threadRootId,
          ),
          ChatSendCodeButton(draftKey: draftKey, threadRootId: threadRootId),
          ChatAiComposeButton(draftKey: draftKey, text: text, focus: focus),
          const _MarkdownToggle(),
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChatReplySuggestionsBar(draftKey: draftKey, text: text, focus: focus),
        ChatStickerSuggestionsBar(
          draftKey: draftKey,
          text: text,
          focus: focus,
          threadRootId: threadRootId,
        ),
        tools,
      ],
    );
  }
}

/// Right of the input: 👍 sends a like while the input is empty; once there
/// is text it becomes the send button. Rebuilt only when the input turns
/// empty or not, not on every key.
class ChatComposerSendButton extends StatefulWidget {
  const ChatComposerSendButton({
    super.key,
    required this.text,
    required this.onSend,
    required this.onLike,
  });

  final ChatComposerController text;
  final VoidCallback onSend;
  final VoidCallback onLike;

  @override
  State<ChatComposerSendButton> createState() => _ChatComposerSendButtonState();
}

class _ChatComposerSendButtonState extends State<ChatComposerSendButton> {
  late bool _ready;

  @override
  void initState() {
    super.initState();
    _ready = !widget.text.isBlank;
    widget.text.addListener(_changed);
  }

  @override
  void didUpdateWidget(ChatComposerSendButton old) {
    super.didUpdateWidget(old);
    if (old.text == widget.text) return;
    old.text.removeListener(_changed);
    widget.text.addListener(_changed);
    _changed();
  }

  @override
  void dispose() {
    widget.text.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final ready = !widget.text.isBlank;
    if (ready != _ready) setState(() => _ready = ready);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final box = BoxConstraints.tightFor(
      width: context.sizes.controlLg,
      height: context.sizes.controlLg,
    );
    return _ready
        ? IconButton(
            tooltip: '${l.chatSend} · ${l.chatSendHint}',
            onPressed: widget.onSend,
            padding: EdgeInsets.zero,
            constraints: box,
            style: IconButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: c.onAccent,
            ),
            icon: Icon(LucideIcons.send500, size: context.sizes.iconLg),
          )
        // The emoji itself, as it is what gets sent.
        : IconButton(
            tooltip: l.chatSendLike,
            onPressed: widget.onLike,
            padding: EdgeInsets.zero,
            constraints: box,
            mouseCursor: WidgetStateMouseCursor.clickable,
            icon: Text(
              '👍',
              style: context.typography.titleLg.copyWith(
                fontSize: context.spacing.xl5,
                height: 1,
              ),
            ),
          );
  }
}

/// A composer tool: a roomier icon button than `AppIconButton`'s, as the
/// composer's controls are the chat's most used.
class ChatComposerToolButton extends StatelessWidget {
  const ChatComposerToolButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final box = context.sizes.controlLg;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      isSelected: selected,
      iconSize: context.sizes.iconLg,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: box, height: box),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: selected ? c.selectionFill : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.radii.md),
        ),
      ),
      icon: Icon(icon, color: selected ? c.accent : c.textSecondary),
    );
  }
}

/// Turns "send as Markdown" on and off (remembered in settings).
class _MarkdownToggle extends ConsumerWidget {
  const _MarkdownToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(appSettingsProvider.select((s) => s.chatSendMarkdown));
    final l = AppL10n.of(context);
    return ChatComposerToolButton(
      icon: LucideIcons.aLargeSmall300,
      tooltip: on ? l.chatMarkdownOn : l.chatMarkdownOff,
      selected: on,
      onPressed: () =>
          ref.read(appSettingsProvider.notifier).setChatSendMarkdown(!on),
    );
  }
}
