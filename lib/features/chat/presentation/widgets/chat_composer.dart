import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/usecases/is_single_emoji.dart';
import '../providers/chat_providers.dart';
import 'chat_attachments.dart';
import 'chat_composer_field.dart';
import 'chat_composer_toolbar.dart';
import 'chat_file_send.dart';
import 'chat_markdown_controller.dart';
import 'chat_mention_overlay.dart';
import 'chat_snack.dart';
import 'mention_autocomplete.dart';
import 'reply_draft_banner.dart';

/// Message input: Enter sends, Shift+Enter adds a line; pasted files or
/// images are sent as attachments. A message picked with "reply" shows above
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
  final _text = ChatMarkdownController();
  late final _focus = FocusNode(onKeyEvent: _onKey);
  final _mentions = MentionAutocomplete();
  final _undo = UndoHistoryController();

  @override
  void initState() {
    super.initState();
    _text.markdown = ref.read(appSettingsProvider).chatSendMarkdown;
    _text.addListener(() => _mentions.update(_text.value));
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
    _text.dispose();
    _focus.dispose();
    _undo.dispose();
    _mentions.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    final key = event.logicalKey;
    if (_mentionKey(key)) return KeyEventResult.handled;
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
    await previewAndSendChatFiles(
      context,
      ref,
      draftKey: _draftKey,
      files: files,
      threadRootId: widget.threadRootId,
    );
    if (mounted) _focus.requestFocus();
  }

  /// Types "@" at the cursor (after a space if needed): starts a mention.
  void _startMention() {
    final value = _text.value;
    final at = value.selection.isValid
        ? value.selection.baseOffset
        : value.text.length;
    final before = value.text.substring(0, at);
    final insert = before.isEmpty || before.endsWith(' ') ? '@' : ' @';
    _text.value = TextEditingValue(
      text: value.text.replaceRange(at, at, insert),
      selection: TextSelection.collapsed(offset: at + insert.length),
    );
    _focus.requestFocus();
  }

  /// ↑/↓ pick, Enter/Tab insert, Esc close while suggestions are shown.
  bool _mentionKey(LogicalKeyboardKey key) {
    final visible = _mentions.visible;
    if (_mentions.query == null || visible.isEmpty) return false;
    if (key == LogicalKeyboardKey.arrowDown) {
      _mentions.move(1, visible.length);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _mentions.move(-1, visible.length);
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.tab) {
      _mentions.insert(_text, visible[_mentions.highlight]);
    } else if (key == LogicalKeyboardKey.escape) {
      _mentions.dismiss();
    } else {
      return false;
    }
    return true;
  }

  /// Sends [emoji] the way the official client does: shown large, not in a
  /// text bubble. A large emoji can't answer a message, so while replying
  /// (or in a thread) it goes as text with the reply instead.
  Future<void> _sendLargeEmoji(String emoji) async {
    if (_replyToId != null) return _deliver(emoji, const {});
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
    final text = _text.text;
    if (text.trim().isEmpty) return;
    final mentions = Map.of(_mentions.mentions);
    _text.clear();
    _mentions.reset();
    if (mentions.isEmpty && const IsSingleEmoji()(text)) {
      return _sendLargeEmoji(text.trim());
    }
    await _deliver(text, mentions);
  }

  /// Sends [text] as a message, answering the reply draft (or thread root).
  Future<void> _deliver(String text, Map<String, int> mentions) async {
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
          mentions: mentions,
        );
    if (result case Err(:final failure)) {
      if (mounted) showChatFailure(context, failure);
    }
  }

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
    // Zalo-style: a flat full-width bar, tools above the input line.
    return DecoratedBox(
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
              undo: _undo,
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
    );
  }
}
