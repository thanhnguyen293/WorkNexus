import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// The composer's tool row (above the input): send image, attach file,
/// mention someone and the Markdown toggle.
class ChatComposerTools extends StatelessWidget {
  const ChatComposerTools({
    super.key,
    required this.onPickImage,
    required this.onAttach,
    required this.onMention,
  });

  final VoidCallback onPickImage;
  final VoidCallback onAttach;
  final VoidCallback onMention;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: s.lg, vertical: s.xs),
      child: Row(
        children: [
          _ToolButton(
            icon: Icons.image_outlined,
            tooltip: l.chatSendImage,
            onPressed: onPickImage,
          ),
          _ToolButton(
            icon: Icons.attach_file_rounded,
            tooltip: l.chatAttach,
            onPressed: onAttach,
          ),
          _ToolButton(
            icon: Icons.alternate_email_rounded,
            tooltip: l.chatMention,
            onPressed: onMention,
          ),
          const _MarkdownToggle(),
        ],
      ),
    );
  }
}

/// Right of the input: 👍 sends a like while the input is empty; once there
/// is text it becomes the send button.
class ChatComposerSendButton extends StatelessWidget {
  const ChatComposerSendButton({
    super.key,
    required this.text,
    required this.onSend,
    required this.onLike,
  });

  final TextEditingController text;
  final VoidCallback onSend;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    return ValueListenableBuilder(
      valueListenable: text,
      builder: (context, value, _) {
        final ready = value.text.trim().isNotEmpty;
        return ready
            ? IconButton(
                tooltip: '${l.chatSend} · ${l.chatSendHint}',
                onPressed: onSend,
                style: IconButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: c.onAccent,
                ),
                icon: Icon(Icons.send_rounded, size: s.xl4),
              )
            : IconButton(
                tooltip: l.chatSendLike,
                onPressed: onLike,
                icon: Text(
                  '👍',
                  style: context.typography.titleLg.copyWith(
                    fontSize: s.xl5,
                    height: 1,
                  ),
                ),
              );
      },
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
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
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: context.spacing.xl5,
      style: IconButton.styleFrom(
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
    return _ToolButton(
      icon: Icons.text_format_rounded,
      tooltip: on ? l.chatMarkdownOn : l.chatMarkdownOff,
      selected: on,
      onPressed: () =>
          ref.read(appSettingsProvider.notifier).setChatSendMarkdown(!on),
    );
  }
}
