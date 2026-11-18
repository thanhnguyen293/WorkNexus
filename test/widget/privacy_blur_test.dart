import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/widgets/privacy_blur.dart';

/// Whether the blur over the widget holding [text] is on.
bool _blurredOver(WidgetTester tester, String text) => tester
    .widget<ImageFiltered>(
      find.ancestor(of: find.text(text), matching: find.byType(ImageFiltered)),
    )
    .enabled;

Future<TestGesture> _hover(WidgetTester tester, Finder target) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(mouse.removePointer);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(tester.getCenter(target));
  await tester.pump();
  return mouse;
}

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('blurs only while asked to', (tester) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            PrivacyBlur(blurred: true, child: Text('secret')),
            PrivacyBlur(blurred: false, child: Text('plain')),
          ],
        ),
      ),
    );
    expect(_blurredOver(tester, 'secret'), isTrue);
    expect(_blurredOver(tester, 'plain'), isFalse);
  });

  testWidgets('pointing at it shows it until the pointer leaves', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const PrivacyBlur(blurred: true, child: Text('secret'))),
    );
    final mouse = await _hover(tester, find.text('secret'));
    expect(_blurredOver(tester, 'secret'), isFalse);

    await mouse.moveTo(const Offset(1, 1));
    await tester.pump();
    expect(_blurredOver(tester, 'secret'), isTrue);
  });

  testWidgets('keyboard focus inside it shows it', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      _app(
        PrivacyBlur(
          blurred: true,
          child: Focus(focusNode: focus, child: const Text('secret')),
        ),
      ),
    );
    expect(_blurredOver(tester, 'secret'), isTrue);

    focus.requestFocus();
    await tester.pump();
    expect(_blurredOver(tester, 'secret'), isFalse);

    focus.unfocus();
    await tester.pump();
    // The focus change lands as that frame builds; its rebuild is next.
    await tester.pump();
    expect(_blurredOver(tester, 'secret'), isTrue);
  });

  testWidgets('pointing anywhere on a region shows all of its blurs', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const PrivacyRevealRegion(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PrivacyBlur(blurred: true, child: Text('name')),
              PrivacyBlur(blurred: true, child: Text('preview')),
            ],
          ),
        ),
      ),
    );
    await _hover(tester, find.text('name'));
    expect(_blurredOver(tester, 'name'), isFalse);
    expect(_blurredOver(tester, 'preview'), isFalse);
  });

  testWidgets('turning the blur on and off keeps the child state', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    Widget field(bool blurred) => _app(
      PrivacyBlur(
        blurred: blurred,
        child: SizedBox(width: 200, child: TextField(controller: controller)),
      ),
    );
    await tester.pumpWidget(field(false));
    final state = tester.state(find.byType(TextField));

    await tester.pumpWidget(field(true));
    expect(tester.state(find.byType(TextField)), same(state));
  });
}
