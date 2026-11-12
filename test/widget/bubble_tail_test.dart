import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/presentation/widgets/bubble_tail.dart';

void main() {
  const rect = Rect.fromLTWH(0, 0, 200, 80);

  Path path(double topRadius) => const TailedBubbleBorder(
    kind: BubbleTailKind.triangleTop,
    borderRadius: BorderRadius.all(Radius.circular(12)),
    tailOnLeft: true,
  ).copyWithTop(topRadius).getOuterPath(rect);

  test('a top triangle starts below a large top corner, not inside it', () {
    final p = path(12);
    // Left of the box, beside the corner's arc: no tail there.
    expect(p.contains(const Offset(-1, 11)), isFalse);
    // The tip region, below the arc.
    const w = BubbleTail.width;
    expect(
      p.contains(const Offset(-w + 2, 12 + BubbleTail.height * 0.35)),
      isTrue,
    );
  });

  test('with a small top corner the triangle keeps its usual place', () {
    final p = path(4);
    const tip = BubbleTail.topInset + BubbleTail.height * 0.5;
    expect(p.contains(const Offset(-BubbleTail.width + 2, tip)), isTrue);
    expect(p.contains(const Offset(-1, BubbleTail.topInset)), isFalse);
  });

  test('with a tip offset the triangle points there (the avatar centre)', () {
    final p = const TailedBubbleBorder(
      kind: BubbleTailKind.triangleTop,
      borderRadius: BorderRadius.all(Radius.circular(12)),
      tailOnLeft: true,
      tipOffset: 20,
    ).getOuterPath(rect);
    expect(p.contains(const Offset(-BubbleTail.width + 2, 20)), isTrue);
    expect(p.contains(const Offset(-BubbleTail.width + 2, 14)), isFalse);
  });
}

extension on TailedBubbleBorder {
  TailedBubbleBorder copyWithTop(double r) => TailedBubbleBorder(
    kind: kind,
    borderRadius: borderRadius.copyWith(topLeft: Radius.circular(r)),
    tailOnLeft: tailOnLeft,
  );
}
