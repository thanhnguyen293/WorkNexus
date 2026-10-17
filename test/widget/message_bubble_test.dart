import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/core/settings/chat_appearance.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_user.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';
import 'package:work_nexus/features/chat/presentation/widgets/message_bubble.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

import '../support/di_test_harness.dart';

const _users = {
  31: ChatUser(accountId: 'a', userId: 31, account: 'dyno', realname: 'Dyno'),
};

ChatMessage _message(MessageContent content, {bool mine = false}) =>
    ChatMessage(
      accountId: 'a',
      gid: 'g1',
      chatGid: 'c1',
      senderId: 31,
      sentAt: DateTime(2026, 10, 13, 13, 42),
      content: content,
      isMine: mine,
    );

void main() {
  late AppDatabase db;

  setUp(() async => db = await setUpTestLocator());
  tearDown(() async => resetTestLocator(db));

  /// A group message from Dyno, as the first and last of its run.
  Future<void> pump(
    WidgetTester tester,
    MessageContent content, {
    required ChatAppearance appearance,
    bool mine = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialAppSettingsProvider.overrideWithValue(
            AppSettings(chatAppearance: appearance),
          ),
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
          home: Scaffold(
            body: MessageBubble(
              chat: (accountId: 'a', chatGid: 'c1'),
              message: _message(content, mine: mine),
              users: _users,
              onOpenThread: (_) {},
              onReply: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // Telegram and Zalo put the sender's name inside the bubble.
  for (final appearance in [ChatAppearance.telegram, ChatAppearance.zalo]) {
    testWidgets('${appearance.name}: a bare media message still names its '
        'sender', (tester) async {
      await pump(
        tester,
        const MessageContent.emoji('👍'),
        appearance: appearance,
      );
      expect(find.text('Dyno'), findsOneWidget);
      await disposeTree(tester);
    });
  }

  testWidgets('hovering the avatar names the sender, not "Profile"', (
    tester,
  ) async {
    await pump(
      tester,
      const MessageContent.text('hello'),
      appearance: ChatAppearance.zalo,
    );
    expect(find.byTooltip('Dyno'), findsOneWidget);
    expect(find.byTooltip('Profile'), findsNothing);
    // The name over the message says it already: no tooltip repeats it.
    expect(
      find.ancestor(of: find.text('Dyno'), matching: find.byType(Tooltip)),
      findsNothing,
    );
    await disposeTree(tester);
  });

  testWidgets('zentao: own messages sit on the left under a name and time '
      'header', (tester) async {
    await pump(
      tester,
      const MessageContent.text('hello'),
      appearance: ChatAppearance.zentao,
      mine: true,
    );
    expect(find.text('Dyno'), findsOneWidget);
    expect(find.text('13:42'), findsOneWidget);
    // The text starts at the left, after the avatar, not by the right edge.
    final width = tester.getSize(find.byType(MaterialApp)).width;
    expect(tester.getTopLeft(find.text('hello')).dx, lessThan(width / 2));
    // The time is in the header, not under the bubble.
    expect(find.text('13:42'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('telegram: own messages stay on the right', (tester) async {
    await pump(
      tester,
      const MessageContent.text('hello'),
      appearance: ChatAppearance.telegram,
      mine: true,
    );
    final width = tester.getSize(find.byType(MaterialApp)).width;
    expect(tester.getTopRight(find.text('hello')).dx, greaterThan(width / 2));
    await disposeTree(tester);
  });
}
