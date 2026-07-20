import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/board/presentation/widgets/sidebar_primitives.dart';

void main() {
  testWidgets('sidebar sync indicator renders as a compact progress glyph', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        home: const Scaffold(body: Center(child: SidebarSyncIndicator())),
      ),
    );

    final box = tester.getSize(find.byType(SidebarSyncIndicator));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(box.width, 21);
    expect(box.height, 21);
  });
}
