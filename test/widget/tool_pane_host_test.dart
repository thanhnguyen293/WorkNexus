import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/app/shell/tool_pane_host.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/tools/tool_module.dart';
import 'package:work_nexus/core/tools/tool_registry_provider.dart';

const _account = Account(
  id: 'a1',
  workspaceId: 'w1',
  providerType: ProviderType.zentao,
  handle: 'thanh',
);

/// A tool whose pane counts its own taps, standing in for a pane's state
/// (scroll, filter, open branches).
class _Module extends ToolModule {
  const _Module();

  @override
  ProviderType get providerType => ProviderType.zentao;

  @override
  SectionId get defaultSection => const SectionId('docs');

  @override
  Widget buildNavPane(
    BuildContext context,
    Account account,
    ToolLocation location,
  ) => _CounterPane(
    name: location.section.value,
    width: location.section.value == 'docs' ? 300 : 240,
  );
}

class _CounterPane extends StatefulWidget {
  const _CounterPane({required this.name, required this.width});

  final String name;
  final double width;

  @override
  State<_CounterPane> createState() => _CounterPaneState();
}

class _CounterPaneState extends State<_CounterPane> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    height: 100,
    child: TextButton(
      onPressed: () => setState(() => _taps++),
      child: Text('${widget.name}:$_taps'),
    ),
  );
}

AppNavState _at(String section) => AppNavState(
  rail: const RailTarget.account('a1'),
  locations: {'a1': ToolLocation(section: SectionId(section))},
);

void main() {
  Future<void> pump(WidgetTester tester, AppNavState nav) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountsProvider.overrideWith((ref) => Stream.value([_account])),
        toolRegistryProvider.overrideWithValue({
          ProviderType.zentao: const _Module(),
        }),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              ToolPaneHost(nav: nav, hidden: false),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    ),
  );

  testWidgets('a place\'s column keeps its state across a trip elsewhere', (
    tester,
  ) async {
    await pump(tester, _at('docs'));
    await tester.pump();
    await tester.tap(find.text('docs:0'));
    await tester.pump();
    expect(find.text('docs:1'), findsOneWidget);

    await pump(tester, _at('bugs'));
    await tester.pump();
    expect(find.text('bugs:0'), findsOneWidget);
    expect(tester.getSize(find.byType(ToolPaneHost)).width, 240);

    await pump(tester, _at('docs'));
    await tester.pump();
    expect(find.text('docs:1'), findsOneWidget, reason: 'state kept');
    expect(tester.getSize(find.byType(ToolPaneHost)).width, 300);
  });
}
