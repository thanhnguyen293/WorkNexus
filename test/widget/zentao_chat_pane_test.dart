import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
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
  final compacts = <bool>[];
  final module = ZentaoModule(
    chatSection: (_) => const SizedBox.shrink(),
    chatPane: (_, compact) {
      compacts.add(compact);
      return const SizedBox.shrink();
    },
    chatMessagesMinWidth: 520,
  );

  setUp(compacts.clear);

  Future<void> pump(WidgetTester tester, {required double width}) async {
    tester.view.physicalSize = Size(width, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
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
            body: Align(
              alignment: Alignment.topLeft,
              child: ZentaoNavPane(
                account: _account,
                location: const ToolLocation(section: SectionId('zentao.chat')),
                sections: module.sections,
                chatPane: module.chatPane,
                chatMessagesMinWidth: module.chatMessagesMinWidth,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('with room, the chat pane keeps its full width', (tester) async {
    await pump(tester, width: 1200);

    expect(compacts.last, isFalse);
    expect(tester.getSize(find.byType(ToolPaneScaffold)).width, 300);
  });

  testWidgets('in a narrow window, the chat pane collapses to the rail width '
      'so the messages keep their room', (tester) async {
    await pump(tester, width: 680);

    expect(compacts.last, isTrue);
    expect(tester.getSize(find.byType(ToolPaneScaffold)).width, 76);
    // The tabs still fit, one under the other.
    expect(tester.takeException(), isNull);
    expect(find.text('Tasks'), findsOneWidget);
  });
}
