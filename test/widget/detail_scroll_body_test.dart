import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/task_detail/presentation/widgets/detail_scroll_body.dart';

void main() {
  Future<void> pump(WidgetTester tester, DetailLayout layout) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        home: Scaffold(
          body: DetailScrollBody(
            layout: layout,
            content: const Text('content-body'),
            sidebar: const Text('sidebar-meta'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('two pane places the sidebar beside the content', (tester) async {
    await pump(tester, DetailLayout.twoPane);

    final content = tester.getRect(find.text('content-body'));
    final sidebar = tester.getRect(find.text('sidebar-meta'));

    // Sidebar sits to the right of the content, roughly on the same row.
    expect(sidebar.left, greaterThan(content.right));
    expect(tester.takeException(), isNull);
  });

  testWidgets('document stacks the sidebar below a width-capped column', (
    tester,
  ) async {
    await pump(tester, DetailLayout.document);

    final content = tester.getRect(find.text('content-body'));
    final sidebar = tester.getRect(find.text('sidebar-meta'));

    // Sidebar drops below the content in the single reading column.
    expect(sidebar.top, greaterThan(content.top));
    expect(sidebar.left, closeTo(content.left, 1));

    // The reading column is capped, not stretched across the 1200px viewport.
    final column = tester.getSize(
      find
          .ancestor(
            of: find.text('content-body'),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );
    expect(column.width, lessThanOrEqualTo(kDetailDocMaxWidth));
    expect(tester.takeException(), isNull);
  });
}
