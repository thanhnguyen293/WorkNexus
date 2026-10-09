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

  Color bubbleColor(WidgetTester tester) {
    final box = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    return (box.decoration! as BoxDecoration).color!;
  }

  Color tailColor(WidgetTester tester) =>
      tester.widget<BubbleTail>(find.byType(BubbleTail)).color;

  testWidgets('hovering the bubble tints its fill and its tail', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    expect(bubbleColor(tester), fill);
    expect(tailColor(tester), fill);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('hi')));
    await tester.pumpAndSettle();

    final hovered = Color.alphaBlend(tint, fill);
    expect(bubbleColor(tester), hovered);
    expect(tailColor(tester), hovered);

    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(bubbleColor(tester), fill);
  });
}
