import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/presentation/widgets/list_extent_estimate.dart';

void main() {
  test('exact when the whole list is laid out', () {
    final e = ListExtentEstimate();
    expect(
      e.maxScrollOffset(
        lastIndex: 9,
        trailingScrollOffset: 500,
        childCount: 10,
      ),
      500,
    );
  });

  test('extrapolates unseen rows from the average of all rows seen', () {
    final e = ListExtentEstimate();
    // Rows 0..3 measure 400 px: 100 each, 6 more to come.
    expect(
      e.maxScrollOffset(
        lastIndex: 3,
        trailingScrollOffset: 400,
        childCount: 10,
      ),
      1000,
    );
    // Rows 0..4 measure 800 px (row 4 is a 400 px image): average 160.
    expect(
      e.maxScrollOffset(
        lastIndex: 4,
        trailingScrollOffset: 800,
        childCount: 10,
      ),
      800 + 160 * 5,
    );
  });

  test('holds steady while scrolling back over rows already seen', () {
    final e = ListExtentEstimate();
    final far = e.maxScrollOffset(
      lastIndex: 19,
      trailingScrollOffset: 2000,
      childCount: 100,
    );
    // Back near the start, where a window of rows averages very differently.
    expect(
      e.maxScrollOffset(
        lastIndex: 2,
        trailingScrollOffset: 30,
        childCount: 100,
      ),
      far,
    );
    expect(
      e.maxScrollOffset(
        lastIndex: 5,
        trailingScrollOffset: 900,
        childCount: 100,
      ),
      far,
    );
  });

  test('never ends before what is laid out now', () {
    final e = ListExtentEstimate();
    e.maxScrollOffset(lastIndex: 9, trailingScrollOffset: 100, childCount: 10);
    // Rows 0..5 grew (images got their size) past the old total.
    expect(
      e.maxScrollOffset(
        lastIndex: 5,
        trailingScrollOffset: 300,
        childCount: 10,
      ),
      300,
    );
  });

  test('grows by the average for rows added at the end', () {
    final e = ListExtentEstimate();
    e.maxScrollOffset(lastIndex: 9, trailingScrollOffset: 1000, childCount: 10);
    expect(
      e.maxScrollOffset(
        lastIndex: 7,
        trailingScrollOffset: 800,
        childCount: 60,
      ),
      1000 + 100 * 50,
    );
  });

  test('starts over after reset or when rows were removed', () {
    final e = ListExtentEstimate();
    e.maxScrollOffset(
      lastIndex: 49,
      trailingScrollOffset: 5000,
      childCount: 100,
    );
    e.reset();
    expect(
      e.maxScrollOffset(
        lastIndex: 1,
        trailingScrollOffset: 20,
        childCount: 100,
      ),
      1000,
    );
    e.maxScrollOffset(
      lastIndex: 49,
      trailingScrollOffset: 5000,
      childCount: 100,
    );
    // Fewer rows than seen before: the old total no longer applies.
    expect(
      e.maxScrollOffset(lastIndex: 1, trailingScrollOffset: 20, childCount: 10),
      100,
    );
  });
}
