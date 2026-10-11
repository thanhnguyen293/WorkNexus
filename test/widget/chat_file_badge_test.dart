import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_file_badge.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildAppTheme(
    variant: AppThemeVariant.light,
    surface: SurfaceStyle.outline,
    density: AppDensity.comfortable,
  ),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('a moving file keeps its extension under the ring; hover '
      'shows a ✕ that cancels', (tester) async {
    var cancelled = 0;
    await tester.pumpWidget(
      _app(
        ChatFileBadge(
          fileName: 'build.zip',
          busy: true,
          progress: 0.3,
          onCancel: () => cancelled++,
        ),
      ),
    );

    expect(find.text('ZIP'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(LucideIcons.x300), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(ChatFileBadge)));
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.x300), findsOneWidget);
    expect(find.text('ZIP'), findsNothing);

    await tester.tap(find.byIcon(LucideIcons.x300));
    expect(cancelled, 1);
  });

  testWidgets('an idle file shows no ✕ on hover', (tester) async {
    await tester.pumpWidget(
      _app(const ChatFileBadge(fileName: 'notes.pdf', busy: false)),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(ChatFileBadge)));
    await tester.pumpAndSettle();

    expect(find.text('PDF'), findsOneWidget);
    expect(find.byIcon(LucideIcons.x300), findsNothing);
  });
}
