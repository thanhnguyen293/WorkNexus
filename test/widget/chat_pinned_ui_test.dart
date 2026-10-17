import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_user.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_providers.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_layout.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_message_card.dart';
import 'package:work_nexus/features/chat/presentation/widgets/pinned_card_preview.dart';
import 'package:work_nexus/features/chat/presentation/widgets/pinned_message_bar.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  const thread = (accountId: 'acc1', chatGid: 'g1');
  const users = {
    101: ChatUser(
      accountId: 'acc1',
      userId: 101,
      account: 'thanh',
      realname: 'Thành',
    ),
  };

  ChatMessage pinned(int id, String text) => ChatMessage(
    accountId: 'acc1',
    gid: 'msg-$id',
    chatGid: 'g1',
    senderId: 101,
    sentAt: DateTime(2026, 5, 29, 9, 56),
    content: MessageContent.text(text),
    isMine: false,
    serverId: id,
    index: id,
  );

  Widget harness(Widget child, {List<ChatMessage> messages = const []}) =>
      ProviderScope(
        overrides: [
          for (final m in messages)
            chatMessageByIdProvider((
              chat: thread,
              serverId: m.serverId!,
            )).overrideWith((ref) => Stream.value(m)),
          chatCanPinProvider(thread).overrideWith((ref) => false),
        ],
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: const Locale('en'),
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          home: Scaffold(
            body: ChatLayoutScope(
              layout: const ChatLayout(compactList: false, infoRoom: false),
              child: child,
            ),
          ),
        ),
      );

  testWidgets('the bar shows the latest pin and how many others there are', (
    tester,
  ) async {
    final messages = [
      pinned(1, 'first'),
      pinned(2, 'second'),
      pinned(3, 'https://www.notion.so/Daily-Report'),
    ];
    await tester.pumpWidget(
      harness(
        const PinnedMessageBar(
          thread: thread,
          pinnedIds: [1, 2, 3],
          users: users,
        ),
        messages: messages,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Message'), findsOneWidget);
    expect(
      find.text('Thành: https://www.notion.so/Daily-Report'),
      findsOneWidget,
    );
    expect(find.text('+2 pinned'), findsOneWidget);
  });

  testWidgets('a single pin shows no "+N pinned" button', (tester) async {
    await tester.pumpWidget(
      harness(
        const PinnedMessageBar(thread: thread, pinnedIds: [1], users: users),
        messages: [pinned(1, 'only')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('pinned'), findsNothing);
  });

  testWidgets('a card says when the message was sent and links back to it', (
    tester,
  ) async {
    var opened = 0;
    final message = pinned(7, 'https://meet.google.com/xde');
    await tester.pumpWidget(
      harness(
        ChatMessageCard(
          message: message,
          users: users,
          label: 'Pinned message',
          labelIcon: LucideIcons.messageSquareText300,
          body: PinnedCardPreview(message: message),
          onViewOriginal: () => opened++,
        ),
      ),
    );

    expect(find.text('Thành'), findsOneWidget);
    expect(find.text('Pinned message'), findsOneWidget);
    expect(find.text('https://meet.google.com/xde'), findsOneWidget);
    expect(find.byIcon(LucideIcons.link300), findsOneWidget);
    expect(find.text('29/05/2026 at 09:56'), findsOneWidget);

    await tester.tap(find.text('View original message'));
    expect(opened, 1);
  });

  testWidgets('a card without a server id has no link back', (tester) async {
    final message = pinned(8, 'plain words').copyWith(serverId: null);
    await tester.pumpWidget(
      harness(
        ChatMessageCard(
          message: message,
          users: users,
          label: 'Pinned message',
          labelIcon: LucideIcons.messageSquareText300,
          body: PinnedCardPreview(message: message),
        ),
      ),
    );

    expect(find.text('View original message'), findsNothing);
    expect(find.byIcon(LucideIcons.link300), findsNothing);
  });
}
