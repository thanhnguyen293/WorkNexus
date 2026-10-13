import 'package:flutter/material.dart';

import 'chat_composer_controller.dart';

/// Someone (or everyone) that can be mentioned.
typedef MentionCandidate = ({int? userId, String name, String? account});

/// Composer state for @mentions: the `@query` typed right before the
/// cursor and the highlighted suggestion.
class MentionAutocomplete extends ChangeNotifier {
  static final _query = RegExp(r'(?:^|\s)@([^\s@]{0,30})$');

  ({int start, String query})? _active;
  int _highlight = 0;

  /// Query start dismissed with Esc: hidden until the user types elsewhere.
  int? _dismissedAt;

  /// The suggestions on screen (set by the list), for keyboard selection.
  List<MentionCandidate> visible = const [];

  String? get query => _active?.query;
  int get highlight => _highlight;

  /// Re-reads the query after every edit or cursor move.
  void update(TextEditingValue value) {
    final sel = value.selection;
    ({int start, String query})? next;
    if (sel.isValid && sel.isCollapsed) {
      final m = _query.firstMatch(value.text.substring(0, sel.baseOffset));
      if (m != null) {
        final q = m[1]!;
        next = (start: sel.baseOffset - q.length - 1, query: q);
      }
    }
    if (next?.start != _dismissedAt) _dismissedAt = null;
    if (next != null && next.start == _dismissedAt) next = null;
    if (next?.query != _active?.query || next?.start != _active?.start) {
      _active = next;
      _highlight = 0;
      notifyListeners();
    }
  }

  void move(int delta, int count) {
    if (count == 0) return;
    _highlight = (_highlight + delta) % count;
    notifyListeners();
  }

  /// Highlights row [index] (mouse hover).
  void highlightAt(int index) {
    if (index == _highlight) return;
    _highlight = index;
    notifyListeners();
  }

  void dismiss() {
    _dismissedAt = _active?.start;
    _active = null;
    notifyListeners();
  }

  /// Replaces the typed `@query` with a mention of [candidate].
  void insert(ChatComposerController text, MentionCandidate candidate) {
    final active = _active;
    if (active == null) return;
    text.insertMention(
      active.start,
      text.selection.baseOffset,
      id: candidate.userId,
      name: candidate.name,
    );
    _active = null;
    notifyListeners();
  }

  /// After sending: no query is pending.
  void reset() {
    _active = null;
    _dismissedAt = null;
  }

  /// [all] filtered by the query (name or account, case-insensitive),
  /// prefix matches first, at most [limit].
  static List<MentionCandidate> filter(
    List<MentionCandidate> all,
    String query, {
    int limit = 8,
  }) {
    final q = query.toLowerCase();
    bool has(MentionCandidate c, bool Function(String) test) =>
        test(c.name.toLowerCase()) || test((c.account ?? '').toLowerCase());
    return [
      ...all.where((c) => has(c, (s) => s.startsWith(q))),
      ...all.where(
        (c) => !has(c, (s) => s.startsWith(q)) && has(c, (s) => s.contains(q)),
      ),
    ].take(limit).toList();
  }
}
