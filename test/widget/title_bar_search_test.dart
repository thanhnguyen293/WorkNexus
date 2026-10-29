import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/app/shell/contextual_search_field.dart';
import 'package:work_nexus/app/shell/title_bar_search.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    bool miniApp = false,
    bool chat = false,
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        miniAppOnScreenProvider.overrideWithValue(miniApp),
        chatOpenProvider.overrideWithValue(chat),
        accountsProvider.overrideWith((ref) => Stream.value(const [])),
        ticketsProvider.overrideWith((ref) => Stream.value(const [])),
      ],
      child: MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('en'),
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        home: const Scaffold(body: TitleBarSearch()),
      ),
    ),
  );

  testWidgets('the ticket search shows on boards and the workspace', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byType(ContextualSearchField), findsOneWidget);
  });

  testWidgets('no ticket search over a mini app', (tester) async {
    await pump(tester, miniApp: true);
    expect(find.byType(ContextualSearchField), findsNothing);
  });

  testWidgets('no ticket search in chat, which has its own', (tester) async {
    await pump(tester, chat: true);
    expect(find.byType(ContextualSearchField), findsNothing);
  });
}
