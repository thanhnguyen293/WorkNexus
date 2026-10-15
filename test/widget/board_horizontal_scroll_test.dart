import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/shared/board/presentation/widgets/board_horizontal_scroll.dart';

void main() {
  testWidgets('the board comes back scrolled where it was left', (
    tester,
  ) async {
    final shown = ValueNotifier(true);
    addTearDown(shown.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: shown,
            // Switching main views drops the board and builds it anew.
            builder: (context, show, _) => show
                ? const BoardHorizontalScroll(
                    child: SizedBox(width: 4000, height: 100),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
    double offset() => tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;

    await tester.drag(
      find.byType(BoardHorizontalScroll),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    final left = offset();
    expect(left, greaterThan(0));

    shown.value = false;
    await tester.pump();
    shown.value = true;
    await tester.pump();

    expect(offset(), left);
  });
}
