import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/app/shell/rail_section_buttons.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/tools/tool_registry_provider.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/tools/zentao/zentao_module.dart';

const _first = Account(
  id: 'zt-1',
  workspaceId: 'ws-1',
  providerType: ProviderType.zentao,
  handle: 'dev_zt',
);
const _second = Account(
  id: 'zt-2',
  workspaceId: 'ws-1',
  providerType: ProviderType.zentao,
  handle: 'qa_zt',
);

/// ZenTao's Tasks and Bugs as rail places of their own: they open the last
/// ZenTao account used, the first one before any.
void main() {
  Future<ProviderContainer> pump(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        toolRegistryProvider.overrideWithValue({
          ProviderType.zentao: const ZentaoModule(),
        }),
        sortedActiveAccountsProvider.overrideWithValue(const [_first, _second]),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          home: const Scaffold(body: RailSectionButtons()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('Bugs opens the first ZenTao account on its bugs', (
    tester,
  ) async {
    final container = await pump(tester);
    expect(find.text('Tasks'), findsOneWidget);

    await tester.tap(find.text('Bugs'));
    await tester.pumpAndSettle();
    final nav = container.read(appNavProvider);
    expect(nav.rail, const RailTarget.account('zt-1'));
    expect(nav.currentLocation?.section, const SectionId('zentao.bugs'));
  });

  testWidgets('a place reopens the ZenTao account used last', (tester) async {
    final container = await pump(tester);
    container.read(appNavProvider.notifier).selectAccount('zt-2');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    final nav = container.read(appNavProvider);
    expect(nav.rail, const RailTarget.account('zt-2'));
    expect(nav.currentLocation?.section, const SectionId('zentao.tasks'));
  });
}
