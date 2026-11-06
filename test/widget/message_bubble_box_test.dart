import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/presentation/widgets/bubble_tail.dart';
import 'package:work_nexus/features/chat/presentation/widgets/message_bubble_box.dart';

void main() {
  const fill = Color(0xFFFFFFFF);
  const tint = Color(0x10000000);

  Widget app() => const MaterialApp(
    home: Scaffold(
      body: Center(
        child: MessageBubbleBox(
          fill: fill,
          hoverFill: tint,
          borderRadius: BorderRadius.zero,
          padding: EdgeInsets.all(8),
          mine: false,
          tail: BubbleTailKind.curlBottom,
          child: Text('hi'),
        ),
      ),
    ),
  );

  // The tail is part of the bubble's own shape: one fill for both.
  ShapeDecoration decoration(WidgetTester tester) =>
      tester
              .widget<AnimatedContainer>(find.byType(AnimatedContainer))
              .decoration!
          as ShapeDecoration;

  Color bubbleColor(WidgetTester tester) => decoration(tester).color!;

  testWidgets('hovering the bubble tints its fill, tail included', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    expect(bubbleColor(tester), fill);
    expect(decoration(tester).shape, isA<TailedBubbleBorder>());

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('hi')));
    await tester.pumpAndSettle();

    final hovered = Color.alphaBlend(tint, fill);
    expect(bubbleColor(tester), hovered);

    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(bubbleColor(tester), fill);
  });

  test('the tail sticks out on the avatar side, outline and all', () {
    const rect = Rect.fromLTWH(10, 0, 100, 40);
    Path pathOf({required bool left}) => TailedBubbleBorder(
      kind: BubbleTailKind.curlBottom,
      borderRadius: BorderRadius.circular(12),
      tailOnLeft: left,
    ).getOuterPath(rect);

    // The curl's tip lies just outside the bottom corner on its side…
    expect(pathOf(left: true).contains(const Offset(10 - 2, 39)), isTrue);
    expect(pathOf(left: false).contains(const Offset(110 + 2, 39)), isTrue);
    // …and nowhere on the other side.
    expect(pathOf(left: true).contains(const Offset(110 + 2, 39)), isFalse);
  });
}
