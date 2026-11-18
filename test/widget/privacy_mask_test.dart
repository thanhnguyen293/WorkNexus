import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/widgets/privacy_mask.dart';

/// Whether the [PrivacyFade] over the widget holding [text] washes it out:
/// any filter but the identity.
bool _fadedOver(WidgetTester tester, String text) =>
    tester
        .widget<ColorFiltered>(
          find.ancestor(
            of: find.text(text),
            matching: find.byType(ColorFiltered),
          ),
        )
        .colorFilter !=
    const ColorFilter.matrix(<double>[
      1, 0, 0, 0, 0, //
      0, 1, 0, 0, 0, //
      0, 0, 1, 0, 0, //
      0, 0, 0, 1, 0, //
    ]);

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

const _surface = Color(0xFF202020);

const _name = PrivacyMask(
  masked: true,
  mask: Text(kPrivacyMaskText),
  child: Text('Alice'),
);

void main() {
  testWidgets('a mask shows dots in place of the text only while masked', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            _name,
            PrivacyMask(
              masked: false,
              mask: Text('hidden'),
              child: Text('Bob'),
            ),
          ],
        ),
      ),
    );
    expect(find.text('Alice'), findsNothing);
    expect(find.text(kPrivacyMaskText), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('pointing at a mask shows the text until the pointer leaves', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_name));
    final mouse = await _hover(tester, find.text(kPrivacyMaskText));
    expect(find.text('Alice'), findsOneWidget);

    await mouse.moveTo(const Offset(1, 1));
    await tester.pump();
    expect(find.text('Alice'), findsNothing);
  });

  testWidgets('a fade washes the message out without changing it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            PrivacyFade(faded: true, color: _surface, child: Text('secret')),
            PrivacyFade(faded: false, color: _surface, child: Text('plain')),
          ],
        ),
      ),
    );
    expect(_fadedOver(tester, 'secret'), isTrue);
    expect(_fadedOver(tester, 'plain'), isFalse);
  });

  testWidgets('keyboard focus inside a fade shows it', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      _app(
        PrivacyFade(
          faded: true,
          color: _surface,
          child: Focus(focusNode: focus, child: const Text('secret')),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    expect(_fadedOver(tester, 'secret'), isFalse);

    focus.unfocus();
    await tester.pump();
    // The focus change lands as that frame builds; its rebuild is next.
    await tester.pump();
    expect(_fadedOver(tester, 'secret'), isTrue);
  });

  testWidgets('pointing anywhere on a region shows all of it', (tester) async {
    await tester.pumpWidget(
      _app(
        const PrivacyRevealRegion(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PrivacyMask(
                masked: true,
                mask: SizedBox(width: 40, height: 20),
                child: Text('avatar'),
              ),
              _name,
            ],
          ),
        ),
      ),
    );
    await _hover(tester, find.text(kPrivacyMaskText));
    expect(find.text('avatar'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('fading in and out keeps the message state', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    Widget field(bool faded) => _app(
      PrivacyFade(
        faded: faded,
        color: _surface,
        child: SizedBox(width: 200, child: TextField(controller: controller)),
      ),
    );
    await tester.pumpWidget(field(false));
    final state = tester.state(find.byType(TextField));

    await tester.pumpWidget(field(true));
    expect(tester.state(find.byType(TextField)), same(state));
  });

  testWidgets('a region around a text field ignores focus', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      _app(
        PrivacyRevealRegion(
          revealOnFocus: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PrivacyFade(
                faded: true,
                color: _surface,
                child: Text('secret'),
              ),
              Focus(focusNode: focus, child: const Text('input')),
            ],
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.pump();
    expect(_fadedOver(tester, 'secret'), isTrue);

    await _hover(tester, find.text('secret'));
    expect(_fadedOver(tester, 'secret'), isFalse);
  });
}
