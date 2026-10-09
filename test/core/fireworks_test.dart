import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/util/fireworks.dart';

void main() {
  const size = Size(1000, 800);

  test('a seed gives the same show every time', () {
    expect(fireworkSparks(size, seed: 7), fireworkSparks(size, seed: 7));
    expect(fireworkSparks(size, seed: 7), hasLength(12 * 48));
  });

  test('bursts go off in the upper part of the area, one after another', () {
    final sparks = fireworkSparks(size, seed: 3);
    for (final s in sparks) {
      expect(s.origin.dx, inInclusiveRange(0, size.width));
      expect(s.origin.dy, lessThan(size.height * 0.6));
      expect(s.start, inInclusiveRange(0, 1));
    }
    final starts = sparks.map((s) => s.start).toSet().toList()..sort();
    expect(starts, hasLength(12));
  });

  test('a spark shows only while its burst lives, fading and falling', () {
    final spark = fireworkSparks(size, seed: 1).first;
    expect(sparkAt(spark, spark.start - 0.01), isNull);
    final early = sparkAt(spark, spark.start + 0.05)!;
    final late = sparkAt(spark, spark.start + 0.3)!;
    expect(late.opacity, lessThan(early.opacity));
    expect(sparkAt(spark, 1.0 + spark.start), isNull);
  });
}
