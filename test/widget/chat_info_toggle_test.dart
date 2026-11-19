import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_info_panel_preference.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_info_panel_providers.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_providers.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_info_toggle.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_layout.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_panels.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

class _MockPreference extends Mock implements ChatInfoPanelPreference {}

const _thread = (accountId: 'acc', chatGid: 'g1');

/// Stands in for the thread pane: names the panel it would show.
class _PanelProbe extends ConsumerWidget {
  const _PanelProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoRoom = ChatLayoutScope.of(context).infoRoom;
    final shown = watchChatInfoShown(ref, _thread, infoRoom: infoRoom);
    return Text(shown ? 'info panel' : 'no panel');
  }
}

void main() {
  late _MockPreference preference;

  setUp(() {
    preference = _MockPreference();
    when(
      () => preference.setVisible(any()),
    ).thenAnswer((_) async => const Ok(null));
  });

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required bool infoRoom,
    bool saved = true,
  }) async {
    when(() => preference.isVisible()).thenAnswer((_) async => Ok(saved));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatInfoPanelPreferenceProvider.overrideWithValue(preference),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(
            body: ChatLayoutScope(
              layout: ChatLayout(infoRoom: infoRoom, compactList: false),
              child: const Column(
                children: [
                  ChatInfoToggle(thread: _thread),
                  _PanelProbe(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(Column)));
  }

  testWidgets('with room, hides the panel, remembers it, and shows it again', (
    tester,
  ) async {
    await pump(tester, infoRoom: true);
    expect(find.text('info panel'), findsOneWidget);
    expect(find.byTooltip('Hide chat info'), findsOneWidget);

    await tester.tap(find.byType(ChatInfoToggle));
    await tester.pumpAndSettle();

    expect(find.text('no panel'), findsOneWidget);
    expect(find.byTooltip('Show chat info'), findsOneWidget);
    verify(() => preference.setVisible(false)).called(1);

    await tester.tap(find.byType(ChatInfoToggle));
    await tester.pumpAndSettle();

    expect(find.text('info panel'), findsOneWidget);
    verify(() => preference.setVisible(true)).called(1);
  });

  testWidgets('starts hidden when the user hid it last time', (tester) async {
    await pump(tester, infoRoom: true, saved: false);

    expect(find.text('no panel'), findsOneWidget);
    expect(find.byTooltip('Show chat info'), findsOneWidget);
  });

  testWidgets('with room, brings the info back over another open panel', (
    tester,
  ) async {
    final container = await pump(tester, infoRoom: true);
    container.read(chatSidePanelProvider(_thread).notifier).state =
        ChatSidePanel.pinned;
    await tester.pumpAndSettle();
    expect(find.text('no panel'), findsOneWidget);

    await tester.tap(find.byType(ChatInfoToggle));
    await tester.pumpAndSettle();

    expect(find.text('info panel'), findsOneWidget);
    expect(container.read(chatSidePanelProvider(_thread)), isNull);
  });

  testWidgets('without room, opens the panel for now and keeps the choice', (
    tester,
  ) async {
    await pump(tester, infoRoom: false);
    expect(find.text('no panel'), findsOneWidget);

    await tester.tap(find.byType(ChatInfoToggle));
    await tester.pumpAndSettle();
    expect(find.text('info panel'), findsOneWidget);

    await tester.tap(find.byType(ChatInfoToggle));
    await tester.pumpAndSettle();
    expect(find.text('no panel'), findsOneWidget);
    verifyNever(() => preference.setVisible(any()));
  });
}
