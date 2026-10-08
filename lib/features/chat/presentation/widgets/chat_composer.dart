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
import 'chat_composer_toolbar.dart';
import 'chat_snack.dart';
import 'reply_draft_banner.dart';

/// Message input: Enter sends, Shift+Enter inserts a new line. Pasting files
/// or an image (Cmd/Ctrl+V) sends them as attachments; the clip button picks
/// files. A message picked with "reply" is shown above the input and the
/// next send answers it; inside a reply thread ([threadRootId]) sends answer
/// the thread's root unless another message is picked.
class ChatComposer extends ConsumerStatefulWidget {
  const ChatComposer({
    super.key,
    required this.thread,
    this.threadRootId,
    this.hint,
  });

  final ChatThreadKey thread;
  final int? threadRootId;
  final String? hint;

  @override
  ConsumerState<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends ConsumerState<ChatComposer> {
  final _text = TextEditingController();
  late final _focus = FocusNode(onKeyEvent: _onKey);

  ChatComposerKey get _draftKey =>
      (chat: widget.thread, inThread: widget.threadRootId != null);

  /// What the next send replies to: the picked message, else the thread root.
  int? get _replyToId =>
      ref.read(chatReplyDraftProvider(_draftKey))?.serverId ??
      widget.threadRootId;

  void _cancelReply() =>
      ref.read(chatReplyDraftProvider(_draftKey).notifier).state = null;

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
    if (key == LogicalKeyboardKey.escape &&
        ref.read(chatReplyDraftProvider(_draftKey)) != null) {
      _cancelReply();
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
    final replyToId = _replyToId;
    _cancelReply();
    for (final f in files) {
      final result = await controller.sendFile(
        t.accountId,
        t.chatGid,
        name: f.name,
        bytes: f.bytes,
        replyToId: replyToId,
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
    final replyToId = _replyToId;
    _cancelReply();
    final t = widget.thread;
    final result = await ref
        .read(chatControllerProvider)
        .send(
          t.accountId,
          t.chatGid,
          text,
          replyToId: replyToId,
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
    ref.listen(chatReplyDraftProvider(_draftKey), (_, next) {
      if (next != null) _focus.requestFocus();
    });
    final draft = ref.watch(chatReplyDraftProvider(_draftKey));
    return Container(
      padding: EdgeInsets.fromLTRB(s.xl4, s.md, s.xl4, s.xl3),
      color: c.background,
      child: ListenableBuilder(
        listenable: _focus,
        builder: (context, _) {
          final focused = _focus.hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: EdgeInsets.fromLTRB(s.md, s.xs, s.md, s.sm),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: focused ? c.accent : c.border),
              borderRadius: BorderRadius.circular(context.radii.xl),
              // A soft accent ring while typing.
              boxShadow: [
                if (focused)
                  BoxShadow(
                    color: c.accent.withValues(alpha: 0.15),
                    spreadRadius: 3,
                  ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (draft != null)
                  ReplyDraftBanner(
                    message: draft,
                    accountId: widget.thread.accountId,
                    onCancel: () {
                      _cancelReply();
                      _focus.requestFocus();
                    },
                  ),
                TextField(
                  controller: _text,
                  focusNode: _focus,
                  autofocus: widget.threadRootId == null,
                  minLines: 1,
                  maxLines: 10,
                  keyboardType: TextInputType.multiline,
                  style: context.typography.body.copyWith(color: c.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: widget.hint ?? l.chatComposerHint,
                    hintStyle: context.typography.body.copyWith(
                      color: c.textTertiary,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: s.sm,
                      vertical: s.lg,
                    ),
                  ),
                ),
                ChatComposerToolbar(
                  text: _text,
                  focused: focused,
                  onPickImage: () => _pick(imagesOnly: true),
                  onAttach: _pick,
                  onSend: _send,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
