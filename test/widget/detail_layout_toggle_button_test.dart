import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/shared/detail/presentation/widgets/detail_layout_toggle_button.dart';

void main() {
  testWidgets('picks the detail layout and persists each change', (
    tester,
  ) async {
    final persisted = <DetailLayout>[];
    final container = ProviderContainer(
      overrides: [
        settingsPersistProvider.overrideWithValue(
          (s) => persisted.add(s.detailLayout),
        ),
      ],
    );
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
          home: const Scaffold(body: Center(child: DetailLayoutToggleButton())),
        ),
      ),
    );

    // Both layouts are in sight, each named by its tooltip.
    final twoPane = find.byTooltip('Two-pane layout');
    final document = find.byTooltip('Document layout');
    expect(find.byIcon(LucideIcons.panelRight300), findsOneWidget);
    expect(find.byIcon(LucideIcons.panelLeftRightDashed300), findsOneWidget);

    // Picking the current layout again changes nothing.
    await tester.tap(twoPane);
    await tester.pumpAndSettle();
    expect(persisted, isEmpty);

    await tester.tap(document);
    await tester.pumpAndSettle();
    expect(
      container.read(appSettingsProvider).detailLayout,
      DetailLayout.document,
    );

    await tester.tap(twoPane);
    await tester.pumpAndSettle();
    expect(
      container.read(appSettingsProvider).detailLayout,
      DetailLayout.twoPane,
    );
    expect(persisted, [DetailLayout.document, DetailLayout.twoPane]);
  });
}
