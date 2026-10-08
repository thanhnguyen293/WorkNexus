import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_providers.dart';
import 'attachment_preview_dialog.dart';
import 'chat_attachments.dart';
import 'chat_snack.dart';

/// Message input: Enter sends, Shift+Enter inserts a new line. Pasting files
/// or an image (Cmd/Ctrl+V) sends them as attachments; the clip button picks
/// files. With [replyToId] everything is sent as a reply in that thread.
class ChatComposer extends ConsumerStatefulWidget {
  const ChatComposer({
    super.key,
    required this.thread,
    this.replyToId,
    this.hint,
  });

  final ChatThreadKey thread;
  final int? replyToId;
  final String? hint;

  @override
  ConsumerState<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends ConsumerState<ChatComposer> {
  final _text = TextEditingController();
  late final _focus = FocusNode(onKeyEvent: _onKey);

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    final key = event.logicalKey;
    if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        !keys.isShiftPressed) {
      _send();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyV &&
        (keys.isMetaPressed || keys.isControlPressed)) {
      // The clipboard can only be inspected asynchronously, so paste is taken
      // over: attachments are sent, plain text is inserted by hand.
      _paste();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _paste() async {
    final files = await readClipboardAttachments();
    if (files != null) {
      if (files.isNotEmpty) await _confirmAndSend(files);
      return;
    }
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (text == null || text.isEmpty || !mounted) return;
    final value = _text.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    _text.value = value.copyWith(
      text: value.text.replaceRange(selection.start, selection.end, text),
      selection: TextSelection.collapsed(offset: selection.start + text.length),
    );
  }

  Future<void> _pick({bool imagesOnly = false}) async {
    final files = await pickChatAttachments(imagesOnly: imagesOnly);
    if (files.isNotEmpty) await _confirmAndSend(files);
  }

  /// Shows the preview; sends what the user kept.
  Future<void> _confirmAndSend(List<ChatAttachment> files) async {
    if (!mounted) return;
    final chosen = await AttachmentPreviewDialog.show(context, files);
    if (chosen != null && chosen.isNotEmpty) await _sendFiles(chosen);
    if (mounted) _focus.requestFocus();
  }

  Future<void> _sendFiles(List<ChatAttachment> files) async {
    final t = widget.thread;
    final controller = ref.read(chatControllerProvider);
    for (final f in files) {
      final result = await controller.sendFile(
        t.accountId,
        t.chatGid,
        name: f.name,
        bytes: f.bytes,
        replyToId: widget.replyToId,
      );
      if (result case Err(:final failure)) {
        if (mounted) showChatFailure(context, failure);
      }
    }
  }

  Future<void> _send() async {
    final text = _text.text;
    if (text.trim().isEmpty) return;
    _text.clear();
    final t = widget.thread;
    final result = await ref
        .read(chatControllerProvider)
        .send(
          t.accountId,
          t.chatGid,
          text,
          replyToId: widget.replyToId,
          markdown: ref.read(appSettingsProvider).chatSendMarkdown,
        );
    if (result case Err(:final failure)) {
      if (mounted) showChatFailure(context, failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final s = context.spacing;
    final tool = c.textSecondary;
    return Container(
      padding: EdgeInsets.fromLTRB(s.xl4, s.md, s.xl4, s.xl3),
      color: c.background,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xs),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(context.radii.xl),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: l.chatSendImage,
              onPressed: () => _pick(imagesOnly: true),
              icon: Icon(Icons.image_outlined, color: tool),
            ),
            IconButton(
              tooltip: l.chatAttach,
              onPressed: _pick,
              icon: Icon(Icons.attach_file_rounded, color: tool),
            ),
            const _MarkdownToggle(),
            SizedBox(width: s.xs),
            Expanded(
              child: TextField(
                controller: _text,
                focusNode: _focus,
                autofocus: widget.replyToId == null,
                minLines: 1,
                maxLines: 8,
                keyboardType: TextInputType.multiline,
                style: context.typography.body.copyWith(color: c.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: widget.hint ?? l.chatComposerHint,
                  hintStyle: context.typography.body.copyWith(
                    color: c.textTertiary,
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: s.lg),
                ),
              ),
            ),
            ValueListenableBuilder(
              valueListenable: _text,
              builder: (context, value, _) {
                final ready = value.text.trim().isNotEmpty;
                return Padding(
                  padding: EdgeInsets.all(s.xs),
                  child: Tooltip(
                    message: l.chatComposerHint,
                    child: Material(
                      color: ready ? c.accent : c.surfaceSubtle,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: ready ? _send : null,
                        child: Padding(
                          padding: EdgeInsets.all(s.md),
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            size: s.xl4,
                            color: ready ? c.onAccent : c.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
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
    final c = context.colors;
    return IconButton(
      tooltip: on ? l.chatMarkdownOn : l.chatMarkdownOff,
      isSelected: on,
      onPressed: () =>
          ref.read(appSettingsProvider.notifier).setChatSendMarkdown(!on),
      icon: Icon(
        Icons.text_format_rounded,
        color: on ? c.accent : c.textSecondary,
      ),
    );
  }
}
