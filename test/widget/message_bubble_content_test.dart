import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';
import 'package:work_nexus/features/chat/presentation/widgets/mention_text.dart';
import 'package:work_nexus/features/chat/presentation/widgets/message_bubble_content.dart';
import 'package:work_nexus/features/chat/presentation/widgets/message_footer.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

import '../support/di_test_harness.dart';

ChatMessage _message(MessageContent content) => ChatMessage(
  accountId: 'a',
  gid: 'g1',
  chatGid: 'c1',
  senderId: 3,
  sentAt: DateTime(2026, 10, 13, 10, 52),
  content: content,
  isMine: false,
);

void main() {
  late AppDatabase db;

  setUp(() async => db = await setUpTestLocator());
  tearDown(() async => resetTestLocator(db));

  Future<void> pump(
    WidgetTester tester,
    MessageContent content, {
    int? replies,
    VoidCallback? onOpenReplies,
  }) async {
    final message = _message(content);
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
              child: SizedBox(
                width: 400,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: MessageBubbleContent(
                    key: const Key('content'),
                    accountId: 'a',
                    message: message,
                    timeAtEnd: true,
                    footer: MessageFooter(
                      accountId: 'a',
                      message: message,
                      replies: replies,
                      onOpenReplies: onOpenReplies,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // The visible time; its invisible twin only keeps the room.
  Finder time() => find.text('10:52').hitTestable();

  testWidgets('the time sits on a row of its own under the text, at the end', (
    tester,
  ) async {
    await pump(tester, const MessageContent.text('ok bác ạ'));
    final text = tester.getRect(find.byType(MentionText));
    final at = tester.getRect(time());
    final content = tester.getRect(find.byKey(const Key('content')));

    expect(at.top, greaterThanOrEqualTo(text.bottom));
    expect(at.right, content.right);
    expect(content.width, lessThan(400), reason: 'no wider than its content');
    await disposeTree(tester);
  });

  testWidgets('message text is selectable, with mentions and links still '
      'tappable', (tester) async {
    await pump(
      tester,
      const MessageContent.text('hi [@Dyno](@#31) see https://a.dev/x'),
    );

    final text = tester.widget<SelectableText>(find.byType(SelectableText));
    final spans = [
      for (final span in text.textSpan!.children!) span as TextSpan,
    ];
    final mention = spans.firstWhere((s) => s.text == '@Dyno');
    final link = spans.firstWhere((s) => s.text == 'https://a.dev/x');
    expect(mention.recognizer, isNotNull);
    expect(link.recognizer, isNotNull);
    await disposeTree(tester);
  });

  testWidgets('code puts the time on a row of its own, at the end', (
    tester,
  ) async {
    await pump(tester, const MessageContent.code('a\nb'));
    final at = tester.getRect(time());
    final content = tester.getRect(find.byKey(const Key('content')));
    final code = tester.getRect(find.byType(SelectableText));

    expect(at.top, greaterThanOrEqualTo(code.bottom));
    expect(at.right, content.right);
    await disposeTree(tester);
  });

  testWidgets('a thread root shows its reply count by the time', (
    tester,
  ) async {
    var opened = 0;
    await pump(
      tester,
      const MessageContent.text('có như photoshop ko bác'),
      replies: 1,
      onOpenReplies: () => opened++,
    );
    await tester.tap(find.text('1').hitTestable());
    expect(opened, 1);
    await disposeTree(tester);
  });
}
