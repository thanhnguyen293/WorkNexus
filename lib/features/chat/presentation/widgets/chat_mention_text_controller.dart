import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// A mention in plain text: `@Name` at [start]–[end] of the text, meaning
/// user [id].
typedef ChatTextMention = ({int start, int end, int id});

/// The plain composer's text: a [TextEditingController] that also knows
/// which `@Name`s are mentions. A mention moves with the text around it,
/// is deleted whole when a deletion reaches into it, and becomes plain text
/// when typed into. Mentions are drawn in the accent.
class ChatMentionTextController extends TextEditingController {
  List<ChatTextMention> _mentions = const [];

  /// The mentions, in text order.
  List<ChatTextMention> get mentions => _mentions;

  @override
  set value(TextEditingValue next) {
    final previous = text;
    if (_mentions.isEmpty || next.text == previous) {
      super.value = next;
      return;
    }
    var edit = _editBetween(previous, next);
    // A mention is one unit: deleting into it deletes it whole. Left alone
    // while an IME is composing, whose text must stay as the IME has it.
    if (edit.inserted == 0 && !next.composing.isValid) {
      var start = edit.start;
      var end = edit.oldEnd;
      for (final m in _mentions) {
        if (m.start < end && m.end > start) {
          start = math.min(start, m.start);
          end = math.max(end, m.end);
        }
      }
      if (start != edit.start || end != edit.oldEnd) {
        edit = (start: start, oldEnd: end, inserted: 0);
        next = TextEditingValue(
          text: previous.replaceRange(start, end, ''),
          selection: TextSelection.collapsed(offset: start),
        );
      }
    }
    _mentions = _shift(_mentions, edit);
    super.value = next;
  }

  /// Puts [replacement] in place of [start]–[end], the caret after it.
  void replace(int start, int end, String replacement) {
    value = TextEditingValue(
      text: text.replaceRange(start, end, replacement),
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
  }

  /// Puts [replacement] in place of the selection (or at the end).
  void replaceSelection(String replacement) {
    final selection = this.selection.isValid
        ? this.selection
        : TextSelection.collapsed(offset: text.length);
    replace(selection.start, selection.end, replacement);
  }

  /// Replaces [start]–[end] (the typed `@query`) with a mention of [name]
  /// and a space.
  void insertMention(
    int start,
    int end, {
    required int id,
    required String name,
  }) {
    final label = '@$name';
    replace(start, end, '$label ');
    _mentions = [
      ..._mentions,
      (start: start, end: start + label.length, id: id),
    ]..sort((a, b) => a.start.compareTo(b.start));
    notifyListeners();
  }

  /// Replaces everything with [text] holding [mentions], the caret at the
  /// end.
  void setContent(String text, List<ChatTextMention> mentions) {
    _mentions = const [];
    value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _mentions = List.unmodifiable(mentions);
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // The composing underline is drawn by the default span.
    if (_mentions.isEmpty || withComposing && value.isComposingRangeValid) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final mention = (style ?? const TextStyle()).copyWith(
      color: context.colors.accent,
      fontWeight: FontWeight.w600,
    );
    final children = <TextSpan>[];
    var at = 0;
    for (final m in _mentions) {
      if (m.start > at) {
        children.add(TextSpan(text: text.substring(at, m.start)));
      }
      children.add(
        TextSpan(text: text.substring(m.start, m.end), style: mention),
      );
      at = m.end;
    }
    if (at < text.length) children.add(TextSpan(text: text.substring(at)));
    return TextSpan(style: style, children: children);
  }
}

/// What an edit changed: [start]–[oldEnd] of the old text was replaced by
/// [inserted] characters.
typedef _EditRange = ({int start, int oldEnd, int inserted});

/// The changed range between [previous] and [next]: what they share at
/// both ends is unchanged. A typed run ends at the caret, which settles
/// where it began when the same letter repeats ("@An" → "@Ann").
_EditRange _editBetween(String previous, TextEditingValue next) {
  final text = next.text;
  final shortest = math.min(previous.length, text.length);
  var prefix = 0;
  while (prefix < shortest &&
      previous.codeUnitAt(prefix) == text.codeUnitAt(prefix)) {
    prefix++;
  }
  final grown = text.length - previous.length;
  final caret = next.selection;
  if (grown > 0 && caret.isValid && caret.isCollapsed) {
    prefix = math.max(0, math.min(prefix, caret.baseOffset - grown));
  }
  var suffix = 0;
  while (suffix < shortest - prefix &&
      previous.codeUnitAt(previous.length - 1 - suffix) ==
          text.codeUnitAt(text.length - 1 - suffix)) {
    suffix++;
  }
  return (
    start: prefix,
    oldEnd: previous.length - suffix,
    inserted: text.length - suffix - prefix,
  );
}

/// [mentions] after [edit]: those before it stay, those after it move by
/// the change in length, those it touches are gone.
List<ChatTextMention> _shift(List<ChatTextMention> mentions, _EditRange edit) {
  final delta = edit.inserted - (edit.oldEnd - edit.start);
  return List.unmodifiable([
    for (final m in mentions)
      if (m.end <= edit.start)
        m
      else if (m.start >= edit.oldEnd)
        (start: m.start + delta, end: m.end + delta, id: m.id),
  ]);
}
