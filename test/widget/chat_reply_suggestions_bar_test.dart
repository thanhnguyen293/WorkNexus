import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_ai_providers.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_composer_controller.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_reply_suggestions_bar.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

const _key = (chat: (accountId: 'a', chatGid: 'c'), inThread: false);

/// Starts in [initial] instead of asking the AI.
class _Suggestions extends ChatReplySuggestionsController {
  _Suggestions(super.composer, this.initial);

  final AsyncValue<List<String>> initial;

  @override
  AsyncValue<List<String>>? build() => initial;
}

void main() {
  late ChatComposerController text;

  setUp(() => text = ChatComposerController());
  tearDown(() => text.dispose());

  Future<void> pump(WidgetTester tester, AsyncValue<List<String>> state) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatReplySuggestionsProvider.overrideWith2(
              (key) => _Suggestions(key, state),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            theme: buildAppTheme(
              variant: AppThemeVariant.dark,
              surface: SurfaceStyle.outline,
              density: AppDensity.comfortable,
            ),
            home: Scaffold(
              body: ChatReplySuggestionsBar(
                draftKey: _key,
                text: text,
                focus: FocusNode(),
              ),
            ),
          ),
        ),
      );

  testWidgets('a picked reply goes into the input, and the tray closes', (
    tester,
  ) async {
    await pump(tester, const AsyncData(['Ok anh', 'Chiều nay em push']));

    expect(find.text('Pick one to edit it before sending'), findsOneWidget);
    await tester.tap(find.text('Chiều nay em push'));
    await tester.pump();

    expect(text.plainText, 'Chiều nay em push');
    expect(find.text('Pick one to edit it before sending'), findsNothing);
  });

  testWidgets('a failure shows in the header, with no replies', (tester) async {
    await pump(tester, const AsyncError('offline', StackTrace.empty));

    expect(find.text("The AI couldn't answer: offline"), findsOneWidget);
    expect(find.byType(InkWell), findsWidgets, reason: 'the close button');
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    expect(find.textContaining("couldn't answer"), findsNothing);
  });
}
