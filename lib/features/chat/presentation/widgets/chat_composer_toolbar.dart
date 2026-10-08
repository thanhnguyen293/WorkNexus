import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// The composer's bottom row: attach image / file and the Markdown toggle
/// on the left; the key hint (while typing) and the send button on the
/// right. The send button lights up once there is text.
class ChatComposerToolbar extends StatelessWidget {
  const ChatComposerToolbar({
    super.key,
    required this.text,
    required this.focused,
    required this.onPickImage,
    required this.onAttach,
    required this.onSend,
  });

  final TextEditingController text;
  final bool focused;
  final VoidCallback onPickImage;
  final VoidCallback onAttach;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    return Row(
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
        const _MarkdownToggle(),
        const Spacer(),
        ValueListenableBuilder(
          valueListenable: text,
          builder: (context, value, _) {
            final ready = value.text.trim().isNotEmpty;
            return Row(
              children: [
                if (focused && ready)
                  Padding(
                    padding: EdgeInsets.only(right: s.lg),
                    child: Text(
                      l.chatSendHint,
                      style: context.typography.caption.copyWith(
                        color: c.textTertiary,
                      ),
                    ),
                  ),
                Tooltip(
                  message: l.chatSend,
                  child: Material(
                    color: ready ? c.accent : c.surfaceSubtle,
                    borderRadius: BorderRadius.circular(context.radii.md),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(context.radii.md),
                      onTap: ready ? onSend : null,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: s.lg,
                          vertical: s.sm,
                        ),
                        child: Icon(
                          Icons.send_rounded,
                          size: s.xl3,
                          color: ready ? c.onAccent : c.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// A compact icon button of the toolbar.
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
      visualDensity: VisualDensity.compact,
      iconSize: context.spacing.xl4,
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
