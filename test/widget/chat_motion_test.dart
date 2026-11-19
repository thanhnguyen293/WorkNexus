import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_motion.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/app_entrance.dart';
import 'package:work_nexus/core/widgets/privacy_mask.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_layout.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_side_panel_host.dart';

/// [child] in an app, with the platform asking for less motion or not.
Widget _app(Widget child, {bool reduced = false}) => MaterialApp(
  theme: buildAppTheme(
    variant: AppThemeVariant.light,
    surface: SurfaceStyle.outline,
    density: AppDensity.comfortable,
  ),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(body: child),
  ),
);

/// The opacity [text] is drawn at, through every fade above it.
double _opacityOf(WidgetTester tester, String text) => tester
    .widgetList<FadeTransition>(
      find.ancestor(of: find.text(text), matching: find.byType(FadeTransition)),
    )
    .fold(1.0, (o, f) => o * f.opacity.value);

Widget _host(Widget? panel, {bool reduced = false}) => _app(
  ChatSidePanelHost(
    messages: const Text('messages'),
    panel: panel,
    onDismiss: () {},
  ),
  reduced: reduced,
);

/// Counts how often it is created, standing in for the message list.
class _Counted extends StatefulWidget {
  const _Counted(this.created);

  final List<int> created;

  @override
  State<_Counted> createState() => _CountedState();
}

class _CountedState extends State<_Counted> {
  @override
  void initState() {
    super.initState();
    widget.created.add(1);
  }

  @override
  Widget build(BuildContext context) => const Text('messages');
}

void main() {
  testWidgets('an entrance fades its child in once', (tester) async {
    await tester.pumpWidget(_app(const AppEntrance(child: Text('chat'))));
    await tester.pump(AppMotion.base ~/ 3);
    expect(_opacityOf(tester, 'chat'), inExclusiveRange(0, 1));

    await tester.pumpAndSettle();
    expect(_opacityOf(tester, 'chat'), 1);
  });

  testWidgets('an entrance shows its child at once with less motion or '
      'when not asked to animate', (tester) async {
    await tester.pumpWidget(
      _app(const AppEntrance(child: Text('chat')), reduced: true),
    );
    final fade = find.descendant(
      of: find.byType(AppEntrance),
      matching: find.byType(FadeTransition),
    );
    expect(fade, findsNothing);

    await tester.pumpWidget(
      _app(const AppEntrance(animate: false, child: Text('row'))),
    );
    expect(fade, findsNothing);
  });

  testWidgets('a panel over the messages slides out before it goes', (
    tester,
  ) async {
    await tester.pumpWidget(_host(null));
    await tester.pumpWidget(_host(const Text('panel')));
    await tester.pump(AppMotion.slow ~/ 2);
    final width = tester.getSize(find.byType(Scaffold)).width;
    final midway = tester.getTopLeft(find.text('panel')).dx;
    await tester.pumpAndSettle();
    final open = tester.getTopLeft(find.text('panel')).dx;
    expect(midway, greaterThan(open), reason: 'still sliding in');
    expect(open, lessThan(width));

    await tester.pumpWidget(_host(null));
    await tester.pump(AppMotion.base ~/ 2);
    expect(find.text('panel'), findsOneWidget, reason: 'sliding out');
    await tester.pumpAndSettle();
    expect(find.text('panel'), findsNothing);
    expect(find.text('messages'), findsOneWidget);
  });

  testWidgets('with less motion a panel comes and goes at once', (
    tester,
  ) async {
    await tester.pumpWidget(_host(null, reduced: true));
    await tester.pumpWidget(_host(const Text('panel'), reduced: true));
    final open = tester.getTopLeft(find.text('panel'));
    await tester.pump(AppMotion.slow);
    expect(tester.getTopLeft(find.text('panel')), open);

    await tester.pumpWidget(_host(null, reduced: true));
    await tester.pump();
    expect(find.text('panel'), findsNothing);
  });

  testWidgets('with less motion a mask swaps text and dots at once', (
    tester,
  ) async {
    Widget name(bool masked) => _app(
      PrivacyMask(
        masked: masked,
        mask: const Text(kPrivacyMaskText),
        child: const Text('Alice'),
      ),
      reduced: true,
    );
    await tester.pumpWidget(name(false));
    await tester.pumpWidget(name(true));
    await tester.pump();
    expect(find.text('Alice'), findsNothing);
    expect(find.text(kPrivacyMaskText), findsOneWidget);
  });

  testWidgets('the messages keep their state as the window is resized across '
      'the width where a panel moves beside them', (tester) async {
    final created = <int>[];
    Widget host({required bool infoRoom, Widget? panel}) => _app(
      ChatLayoutScope(
        layout: ChatLayout(infoRoom: infoRoom, compactList: false),
        child: ChatSidePanelHost(
          messages: _Counted(created),
          panel: panel,
          onDismiss: () {},
        ),
      ),
    );
    for (final panel in [null, const Text('panel')]) {
      await tester.pumpWidget(host(infoRoom: true, panel: panel));
      await tester.pumpAndSettle();
      created.clear();
      for (var i = 0; i < 4; i++) {
        await tester.pumpWidget(
          host(infoRoom: i.isEven ? false : true, panel: panel),
        );
        await tester.pump();
      }
      expect(created, isEmpty, reason: 'rebuilt from scratch');
      expect(find.text('messages'), findsOneWidget);
    }
  });
}
