import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/task_detail/presentation/widgets/bug_description.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  Future<void> pump(WidgetTester tester, String body) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        home: Scaffold(
          body: SingleChildScrollView(child: BugDescription(body: body)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const structured = '''
**Steps to reproduce:**

1. Open SocialFi
2. User A taps Add Friend

**Actual result:**

Friend count increases for both users.

**Expected result:**

Count should only increase once both connect.
''';

  testWidgets('groups the three sections without exceptions', (tester) async {
    await pump(tester, structured);

    expect(tester.takeException(), isNull);
    expect(find.text('Steps to reproduce'), findsOneWidget);
    expect(find.text('Actual result'), findsOneWidget);
    expect(find.text('Expected result'), findsOneWidget);
    // Content is still rendered as markdown, nothing dropped.
    expect(find.textContaining('Open SocialFi'), findsOneWidget);
    expect(find.textContaining('Friend count increases'), findsOneWidget);
    expect(find.textContaining('only increase once both'), findsOneWidget);
  });

  testWidgets('hides absent sections and keeps free text (no info lost)', (
    tester,
  ) async {
    const partial = '''
Some preamble noting the environment.

**Actual result:**

The app crashes on save.
''';
    await pump(tester, partial);

    expect(tester.takeException(), isNull);
    // The one present section shows; the two absent ones do not.
    expect(find.text('Actual result'), findsOneWidget);
    expect(find.text('Steps to reproduce'), findsNothing);
    expect(find.text('Expected result'), findsNothing);
    // Free text outside any heading is preserved.
    expect(find.textContaining('Some preamble'), findsOneWidget);
    expect(find.textContaining('crashes on save'), findsOneWidget);
  });

  testWidgets('falls back to plain markdown when no headings match', (
    tester,
  ) async {
    await pump(tester, 'Just a plain description with no headings.');

    expect(tester.takeException(), isNull);
    expect(find.text('Steps to reproduce'), findsNothing);
    expect(find.textContaining('Just a plain description'), findsOneWidget);
  });
}
