import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/app/shell/chat_place.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_providers.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/shared/shell_pane/tool_pane_scaffold.dart';
import 'package:work_nexus/tools/zentao/presentation/nav/zentao_nav_pane.dart';
import 'package:work_nexus/tools/zentao/zentao_module.dart';

const _account = Account(
  id: 'acc-zt',
  workspaceId: 'ws-1',
  providerType: ProviderType.zentao,
  handle: 'dev_zt',
);

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required double width,
    required Widget pane,
  }) async {
    tester.view.physicalSize = Size(width, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        // No chat account: the pane's width is what is measured.
        overrides: [selectedChatAccountIdProvider.overrideWithValue(null)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          home: Scaffold(
            body: Align(alignment: Alignment.topLeft, child: pane),
          ),
        ),
      ),
    );
  }

  double paneWidth(WidgetTester tester) =>
      tester.getSize(find.byType(ToolPaneScaffold)).width;

  testWidgets('with room, the chat column keeps its full width', (
    tester,
  ) async {
    await pump(tester, width: 1200, pane: const ChatToolPane());

    expect(paneWidth(tester), 300);
  });

  testWidgets('in a narrow window, the chat column narrows so the messages '
      'keep their room', (tester) async {
    await pump(tester, width: 680, pane: const ChatToolPane());

    expect(paneWidth(tester), 240);
  });

  testWidgets('the ZenTao pane keeps its full width even when narrow', (
    tester,
  ) async {
    const module = ZentaoModule();
    await pump(
      tester,
      width: 680,
      pane: ZentaoNavPane(
        account: _account,
        location: const ToolLocation(section: SectionId('zentao.tasks')),
        sections: module.sections,
      ),
    );

    expect(paneWidth(tester), 300);
    // Tasks and Bugs are rail places, not tabs of the pane.
    expect(find.text('Bugs'), findsNothing);
    expect(find.text('Chat'), findsNothing);
  });
}
