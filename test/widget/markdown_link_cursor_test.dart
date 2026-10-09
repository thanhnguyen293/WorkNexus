import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/markdown_text.dart';

void main() {
  final theme = buildAppTheme(
    variant: AppThemeVariant.light,
    surface: SurfaceStyle.outline,
    density: AppDensity.comfortable,
  );

  Future<MouseCursor?> cursorOverLink(
    WidgetTester tester, {
    void Function(String url)? onLinkTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: MarkdownText(
            'see [the docs](https://example.com) here',
            onLinkTap: onLinkTap,
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('the docs')));
    await tester.pump();
    return RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1);
  }

  testWidgets('a tappable markdown link shows the hand cursor', (tester) async {
    final cursor = await cursorOverLink(tester, onLinkTap: (_) {});
    expect(cursor, SystemMouseCursors.click);
  });

  testWidgets('a link with no tap handler keeps the default cursor', (
    tester,
  ) async {
    final cursor = await cursorOverLink(tester);
    expect(cursor, isNot(SystemMouseCursors.click));
  });
}
