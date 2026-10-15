import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/tools/zentao/presentation/providers/zentao_filter_providers.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_execution_switcher.dart';

void main() {
  Widget buildHarness() {
    return ProviderScope(
      overrides: [
        activeZoneFilterProvider.overrideWith(() => _TestZoneController('VN')),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        home: const Scaffold(body: Center(child: ZenTaoExecutionSwitcher())),
      ),
    );
  }

  testWidgets('renders execution switcher and opens popover on tap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    // Verify breadcrumb label & zone pill
    expect(find.text('Project'), findsOneWidget);
    expect(find.text('Select Project'), findsOneWidget);
    expect(find.text('VN'), findsOneWidget);

    // Tap to open popover
    await tester.tap(find.byType(ZenTaoExecutionSwitcher));
    await tester.pumpAndSettle();

    // Verify popover components
    expect(find.text('Mine'), findsOneWidget);
    expect(find.text('Others'), findsOneWidget);
    expect(find.text('VN'), findsWidgets);
  });
}

class _TestZoneController extends ActiveZoneFilterController {
  _TestZoneController(this._initial);
  final String? _initial;

  @override
  String? build() => _initial;
}
