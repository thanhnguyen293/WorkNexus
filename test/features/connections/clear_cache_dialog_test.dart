import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/connections/domain/entities/cache_section.dart';
import 'package:work_nexus/features/connections/presentation/widgets/clear_cache_dialog.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  testWidgets('every section starts picked; unpicked ones are left out', (
    tester,
  ) async {
    Set<CacheSection>? picked;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => picked = await showClearCacheDialog(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .every((t) => t.value ?? false),
      isTrue,
    );

    await tester.tap(find.text('Chat'));
    await tester.pump();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(picked, {
      CacheSection.tickets,
      CacheSection.dashboard,
      CacheSection.translations,
    });
  });
}
