import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/util/dropped_files.dart';
import '../../../../core/widgets/file_drop_target.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/is_single_emoji.dart';
import '../providers/chat_providers.dart';
import '../providers/chat_staged_files_provider.dart';
import '../providers/chat_typing_providers.dart';
import '../providers/chat_typing_sender.dart';
import 'chat_attachments.dart';
import 'chat_composer_controller.dart';
import 'chat_composer_field.dart';
import 'chat_composer_toolbar.dart';
import 'chat_file_send.dart';
import 'chat_mention_overlay.dart';
import 'chat_snack.dart';
import 'chat_staged_files.dart';
import 'chat_text_send.dart';
import 'mention_autocomplete.dart';
import 'reply_draft_banner.dart';

/// Message input: Enter sends, Shift+Enter adds a line; pasted files or
/// images are sent as attachments; dropped ones wait in the input (which then
/// takes no text) until sent. A message picked with "reply" shows above
/// the input and the next send answers it; in a reply thread
/// ([threadRootId]) sends answer its root unless another message is picked.
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
  late final _text = ChatComposerController(
    markdown: ref.read(appSettingsProvider).chatSendMarkdown,
  );
  final _focus = FocusNode();
  final _mentions = MentionAutocomplete();
  late final ChatTypingSender _typing;

  @override
  void initState() {
    super.initState();
    _typing = chatTypingSenderFor(ref, widget.thread);
    _text.addListener(() {
      _mentions.update(_text.value);
      _typing.changed(_text.value.text);
    });
  }

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
    _typing.stop();
    _text.dispose();
    _focus.dispose();
    _mentions.dispose();
    super.dispose();
  }

  /// Keys the composer takes before the editor; null leaves one to it.
  KeyEventResult? _onKey(KeyEvent event) {
    if (event is KeyUpEvent) return null;
    final keys = HardwareKeyboard.instance;
    final key = event.logicalKey;
    final enter =
        (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        !keys.isShiftPressed;
    // Holding Enter must not type line breaks after the send.
    if (event is KeyRepeatEvent) return enter ? KeyEventResult.handled : null;
    if (_mentions.handleKey(key, _text)) return KeyEventResult.handled;
    if (enter) {
      _send();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape &&
        ref.read(chatReplyDraftProvider(_draftKey)) != null) {
      _cancelReply();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyX &&
        keys.isShiftPressed &&
        (keys.isMetaPressed || keys.isControlPressed)) {
      final settings = ref.read(appSettingsProvider.notifier);
      settings.setChatSendMarkdown(
        !ref.read(appSettingsProvider).chatSendMarkdown,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyV &&
        (keys.isMetaPressed || keys.isControlPressed)) {
      // The clipboard can only be inspected asynchronously, so paste is taken
      // over: attachments are sent, plain text is inserted by hand.
      _paste();
      return KeyEventResult.handled;
    }
    return null;
  }

  Future<void> _paste() async {
    final files = await readClipboardAttachments();
    if (files != null) {
      if (files.isNotEmpty) await _confirmAndSend(files);
      return;
    }
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (text == null || text.isEmpty || !mounted) return;
    _text.insertText(text);
  }

  Future<void> _pick({bool imagesOnly = false}) async {
    final files = await pickChatAttachments(imagesOnly: imagesOnly);
    if (files.isNotEmpty) await _confirmAndSend(files);
  }

  /// Shows the preview; sends what the user kept.
  Future<void> _confirmAndSend(List<ChatAttachment> files) async {
    if (!mounted) return;
    await previewAndSendChatFiles(
      context,
      ref,
      draftKey: _draftKey,
      files: files,
      threadRootId: widget.threadRootId,
    );
    if (mounted) _focus.requestFocus();
  }

  /// Sends files that waited in the input, then goes back to typing.
  Future<void> _sendStaged(List<DroppedFile> files) async {
    _refocus();
    await sendChatFiles(
      context,
      ref,
      draftKey: _draftKey,
      files: files,
      threadRootId: widget.threadRootId,
    );
  }

  /// The text input is back only after the next frame.
  void _refocus() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _focus.requestFocus();
  });

  void _startMention() {
    _mentions.start(_text);
    _focus.requestFocus();
  }

  /// Sends [emoji] the way the official client does: shown large, not in a
  /// text bubble. A large emoji can't answer a message, so while replying
  /// (or in a thread) it goes as text with the reply instead.
  Future<void> _sendLargeEmoji(String emoji) async {
    if (_replyToId != null) return _deliver(emoji);
    final t = widget.thread;
    final result = await ref
        .read(chatControllerProvider)
        .sendLargeEmoji(t.accountId, t.chatGid, emoji);
    if (result case Err(:final failure)) {
      if (mounted) showChatFailure(context, failure);
    }
  }

  /// Sends the input; a lone emoji goes large.
  Future<void> _send() async {
    if (_text.isBlank) return;
    final text = _text.messageText;
    final plain = _text.hasMentions ? null : _text.plainText;
    _text.clear();
    _mentions.reset();
    if (plain != null && const IsSingleEmoji()(plain)) {
      return _sendLargeEmoji(plain.trim());
    }
    await _deliver(text);
  }

  /// Sends [text] as a message, answering the reply draft (or thread root).
  Future<void> _deliver(String text) => sendChatText(
    context,
    ref,
    draftKey: _draftKey,
    text: text,
    threadRootId: widget.threadRootId,
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    ref.listen(
      appSettingsProvider.select((s) => s.chatSendMarkdown),
      (_, on) => _text.markdown = on,
    );
    ref.listen(chatReplyDraftProvider(_draftKey), (_, next) {
      if (next != null) _focus.requestFocus();
    });
    final draft = ref.watch(chatReplyDraftProvider(_draftKey));
    final staged = chatStagedFilesProvider(_draftKey);
    final hasStaged = ref.watch(staged.select((f) => f.isNotEmpty));
    // Zalo-style: a flat full-width bar, tools above the input line.
    return FileDropTarget(
      hint: AppL10n.of(context).dropFilesToStage,
      onDrop: (files) async =>
          ref.read(staged.notifier).state = [...ref.read(staged), ...files],
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: context.hairlineSide),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ChatComposerTools(
              onPickImage: () => _pick(imagesOnly: true),
              onAttach: _pick,
              onMention: _startMention,
              thread: widget.thread,
              draftKey: _draftKey,
              threadRootId: widget.threadRootId,
              text: _text,
              focus: _focus,
            ),
            Divider(height: 1, thickness: 1, color: c.border),
            if (draft != null)
              Padding(
                padding: EdgeInsets.fromLTRB(s.xl, s.md, s.xl, 0),
                child: ReplyDraftBanner(
                  message: draft,
                  accountId: widget.thread.accountId,
                  onCancel: () {
                    _cancelReply();
                    _focus.requestFocus();
                  },
                ),
              ),
            if (hasStaged)
              ChatStagedFiles(
                draftKey: _draftKey,
                onSend: _sendStaged,
                onCleared: _refocus,
              )
            else
              ChatMentionOverlay(
                thread: widget.thread,
                mentions: _mentions,
                focus: _focus,
                onPick: (candidate) {
                  _mentions.insert(_text, candidate);
                  _focus.requestFocus();
                },
                child: ChatComposerField(
                  controller: _text,
                  focus: _focus,
                  onKey: _onKey,
                  autofocus: widget.threadRootId == null,
                  markdown: ref.watch(
                    appSettingsProvider.select((s) => s.chatSendMarkdown),
                  ),
                  hint: widget.hint,
                  onSend: _send,
                  onLike: () => _sendLargeEmoji('👍'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
