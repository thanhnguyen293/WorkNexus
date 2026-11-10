import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// The open document's reading state shared by its page, find bar and
/// outline: which find match is current, which heading is being read, and
/// the keys of the widgets drawn for them so the page can scroll there.
///
/// The marks and heading markers are built once with the page; they follow
/// [current] / [activeHeading] themselves, so stepping through matches or
/// scrolling never rebuilds the (possibly large) page.
class ZenTaoDocReader {
  /// The find match on show, or -1 without matches.
  final current = ValueNotifier<int>(-1);

  /// How many matches the search marked.
  final total = ValueNotifier<int>(0);

  /// The heading the reader is in (the last one scrolled past), or -1.
  final activeHeading = ValueNotifier<int>(-1);

  final _matchKeys = <int, GlobalKey>{};
  final _matchHost = <int, int>{};
  final _headingKeys = <int, GlobalKey>{};

  static const _move = Duration(milliseconds: 220);

  /// The scroll to a heading picked from the outline: longer than [_move],
  /// since it may cross many screens.
  static const _toHeading = Duration(milliseconds: 360);

  /// Counts trips to a heading picked from the outline; [_goingToHeading]
  /// holds while the latest one is under way. The outline lights the picked
  /// heading at once, and the sections the page scrolls past on the way must
  /// not each light up in turn.
  int _trip = 0;
  bool _goingToHeading = false;

  int get matchCount => total.value;

  /// The key of the widget showing match [index] (a mark, or the code block
  /// or inline code holding it).
  GlobalKey matchKey(int index) => _matchKeys.putIfAbsent(index, GlobalKey.new);

  /// Match [index] is drawn inside the widget keyed for match [host].
  void hostMatch(int index, int host) => _matchHost[index] = host;

  GlobalKey headingKey(int index) =>
      _headingKeys.putIfAbsent(index, GlobalKey.new);

  /// A new search marked [count] matches: the first becomes current.
  void resetMatches(int count) {
    total.value = count;
    _matchHost.clear();
    current.value = count > 0 ? 0 : -1;
  }

  void next() => _step(1);

  void previous() => _step(-1);

  void _step(int by) {
    final count = total.value;
    if (count == 0) return;
    current.value = (current.value + by) % count;
    revealCurrent();
  }

  /// Scrolls the current match into view (a third down the page).
  void revealCurrent() {
    final index = current.value;
    if (index < 0) return;
    _scrollTo(() => _matchKeys[_matchHost[index] ?? index], alignment: 0.35);
  }

  /// Scrolls heading [index] near the top of the page: its line's top
  /// [gap] pixels below the page's top edge.
  void goToHeading(int index, {required double gap, int tries = 30}) {
    activeHeading.value = index;
    final context = _headingKeys[index]?.currentContext;
    if (context == null) {
      if (tries == 0) return;
      SchedulerBinding.instance
        ..addPostFrameCallback(
          (_) => goToHeading(index, gap: gap, tries: tries - 1),
        )
        ..scheduleFrame();
      return;
    }
    final scrollable = Scrollable.of(context);
    final viewport = scrollable.context.findRenderObject();
    final top = viewport is RenderBox ? _headingTop(index, viewport) : null;
    if (top == null) return;
    final position = scrollable.position;
    final target = (position.pixels + top - gap).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    final trip = ++_trip;
    _goingToHeading = true;
    position
        .animateTo(target, duration: _toHeading, curve: Curves.easeOut)
        .whenComplete(() {
          // A newer pick took over this trip: leave the state to it.
          if (trip != _trip) return;
          _goingToHeading = false;
          activeHeading.value = index;
        });
  }

  /// Where heading [index] starts, from the top of [viewport]. Its marker is
  /// a zero-size widget on the heading's baseline, so the heading's own text
  /// box — the paragraph holding the marker — gives its top.
  double? _headingTop(int index, RenderBox viewport) {
    RenderObject? node = _headingKeys[index]?.currentContext
        ?.findRenderObject();
    if (node == null || !node.attached) return null;
    final marker = node;
    while (node != null && node is! RenderParagraph) {
      node = node.parent;
    }
    final box = (node ?? marker) as RenderBox;
    return box.localToGlobal(Offset.zero, ancestor: viewport).dy;
  }

  /// Scrolls to the widget [key] names — waiting a few frames for it when
  /// the page is still being built (a long body is built asynchronously).
  void _scrollTo(
    GlobalKey? Function() key, {
    required double alignment,
    int tries = 30,
  }) {
    final context = key()?.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(context, alignment: alignment, duration: _move);
      return;
    }
    if (tries == 0) return;
    SchedulerBinding.instance
      ..addPostFrameCallback(
        (_) => _scrollTo(key, alignment: alignment, tries: tries - 1),
      )
      ..scheduleFrame();
  }

  /// Finds the heading being read: the last one at or above [lead] pixels
  /// from the top of [viewport] — or, at the very end of the page, the last
  /// one on screen, so the closing sections can become active too.
  void trackHeading(
    RenderBox viewport, {
    required double lead,
    required bool atEnd,
  }) {
    if (_goingToHeading) return;
    var active = -1;
    final indices = _headingKeys.keys.toList()..sort();
    for (final index in indices) {
      final y = _headingTop(index, viewport);
      if (y == null) continue;
      if (y <= lead || (atEnd && y < viewport.size.height)) active = index;
    }
    if (active < 0 && indices.isNotEmpty) active = indices.first;
    activeHeading.value = active;
  }

  void dispose() {
    current.dispose();
    total.dispose();
    activeHeading.dispose();
  }
}
