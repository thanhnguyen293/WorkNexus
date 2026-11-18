import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_summary.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_ai_providers.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_ai_catch_up_banner.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_assistant_panel.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_summary_view.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/l10n/app_localizations_en.dart';

const _thread = (accountId: 'a', chatGid: 'c');

const _summary = ChatSummary(
  overview: 'Release planning for Friday.',
  keyPoints: ['Build is green'],
  decisions: ['Ship on Friday'],
  actionItems: [
    ChatActionItem(task: 'Tag the build', owner: 'Minh', due: 'Fri'),
  ],
  messageCount: 42,
  model: 'gemini-flash',
);

Widget _app(Widget child) => ProviderScope(
  overrides: [
    chatAiPeopleProvider.overrideWith(
      (ref, accountId) => (selfName: 'An', nameOf: (id) => 'User $id'),
    ),
  ],
  child: MaterialApp(
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildAppTheme(
      variant: AppThemeVariant.light,
      surface: SurfaceStyle.outline,
      density: AppDensity.comfortable,
    ),
    home: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('the summary shows each section it has, and its source', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const SingleChildScrollView(child: ChatSummaryView(summary: _summary)),
      ),
    );

    expect(find.text('Release planning for Friday.'), findsOneWidget);
    expect(find.text('Key points'), findsOneWidget);
    expect(find.text('Decisions'), findsOneWidget);
    expect(find.text('Action items'), findsOneWidget);
    // No open questions came back, so the section is left out.
    expect(find.text('Open questions'), findsNothing);
    expect(find.text('42 messages · gemini-flash'), findsOneWidget);
  });

  test('a summary copies as plain text, section by section', () {
    expect(
      chatSummaryAsText(AppL10nEn(), _summary),
      'Release planning for Friday.\n\n'
      'Key points\n- Build is green\n\n'
      'Decisions\n- Ship on Friday\n\n'
      'Action items\n- Minh: Tag the build (Due Fri)',
    );
  });

  testWidgets('the catch-up banner offers a summary until dismissed', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const ChatAiCatchUpBanner(thread: _thread)));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChatAiCatchUpBanner)),
    );

    // Few unread messages: nothing to offer.
    container.read(chatUnreadOnOpenProvider(_thread).notifier).state = 5;
    await tester.pump();
    expect(find.text('Summarize'), findsNothing);

    container.read(chatUnreadOnOpenProvider(_thread).notifier).state = 35;
    await tester.pump();
    expect(find.text('35 new messages since you last looked'), findsOneWidget);
    expect(find.text('Summarize'), findsOneWidget);

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump();
    expect(find.text('Summarize'), findsNothing);
  });

  testWidgets('summaries follow the app language until another is picked', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const ChatAssistantPanel(thread: _thread)));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChatAssistantPanel)),
    );

    expect(find.text('Summary language'), findsOneWidget);
    // The app is in English, so are summaries.
    expect(find.text('English'), findsOneWidget);
    expect(container.read(chatSummaryLanguageProvider), isNull);

    await tester.tap(find.byTooltip('Summary language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日本語').last);
    await tester.pumpAndSettle();

    expect(container.read(chatSummaryLanguageProvider), 'ja');
    expect(find.text('日本語'), findsOneWidget);
  });
}
