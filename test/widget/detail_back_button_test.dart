import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/task_detail/presentation/widgets/detail_back_button.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  Future<ProviderContainer> pump(WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const Scaffold(body: DetailBackButton()),
        ),
      ),
    );
    return container;
  }

  testWidgets('hidden on the first ticket, goes back from a later one', (
    tester,
  ) async {
    final container = await pump(tester);
    final nav = container.read(appNavProvider.notifier)..openTicket('parent');
    await tester.pump();
    expect(find.byTooltip('Back'), findsNothing);

    nav.openTicket('child');
    await tester.pump();
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();

    expect(container.read(openTicketIdProvider), 'parent');
    expect(find.byTooltip('Back'), findsNothing);
  });
}
