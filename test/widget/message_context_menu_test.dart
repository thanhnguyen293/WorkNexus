import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/presentation/widgets/message_hover_actions.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  Future<List<String>> pumpBubble(WidgetTester tester) async {
    final ran = <String>[];
    MessageAction action(String name, {bool destructive = false}) => (
      icon: Icons.circle,
      tooltip: name,
      onTap: () => ran.add(name),
      destructive: destructive,
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: Center(
            child: MessageHoverActions(
              alignEnd: false,
              actions: [
                action('Reply'),
                action('Copy'),
                action('Retract', destructive: true),
              ],
              child: const Text('hello'),
            ),
          ),
        ),
      ),
    );
    return ran;
  }

  testWidgets('right-click opens every action and runs the picked one', (
    tester,
  ) async {
    final ran = await pumpBubble(tester);

    await tester.tap(find.text('hello'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.text('Reply'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Retract'), findsOneWidget);

    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(ran, ['Copy']);
    expect(find.text('Retract'), findsNothing);
  });

  testWidgets('clicking outside closes the menu without running anything', (
    tester,
  ) async {
    final ran = await pumpBubble(tester);

    await tester.tap(find.text('hello'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(find.text('Reply'), findsNothing);
    expect(ran, isEmpty);
  });
}
